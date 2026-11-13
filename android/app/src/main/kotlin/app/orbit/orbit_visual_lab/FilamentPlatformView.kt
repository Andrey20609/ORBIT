package app.orbit.orbit_visual_lab

import android.app.Activity
import android.graphics.BitmapFactory
import android.opengl.Matrix
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import android.view.Surface
import android.view.TextureView
import com.google.android.filament.Box
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.Entity
import com.google.android.filament.EntityManager
import com.google.android.filament.Filament
import com.google.android.filament.IndexBuffer
import com.google.android.filament.IndirectLight
import com.google.android.filament.LightManager
import com.google.android.filament.Material
import com.google.android.filament.MaterialInstance
import com.google.android.filament.RenderableManager
import com.google.android.filament.Renderer
import com.google.android.filament.Scene
import com.google.android.filament.Skybox
import com.google.android.filament.SwapChain
import com.google.android.filament.SwapChainFlags
import com.google.android.filament.Texture
import com.google.android.filament.VertexBuffer
import com.google.android.filament.View
import com.google.android.filament.Viewport
import com.google.android.filament.android.ChoreographerHelper
import com.google.android.filament.android.DisplayHelper
import com.google.android.filament.android.FilamentHelper
import com.google.android.filament.android.UiHelper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * A self-contained Filament PBR landscape. All engine objects belong to one view and one thread.
 * The terrain uses procedural normals and quaternion tangent frames, not a painted screenshot.
 */
class FilamentPlatformView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    val viewId: Int,
    initialProfile: String,
    initialQuality: String,
    initialAtmosphereMode: String = "automatic",
) : PlatformView {
    private val textureView = TextureView(activity)
    private val viewChannel = MethodChannel(messenger, "orbit/filament/$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var uiHelper: UiHelper
    private lateinit var displayHelper: DisplayHelper
    private lateinit var frameScheduler: ChoreographerHelper

    private lateinit var engine: Engine
    private lateinit var renderer: Renderer
    private lateinit var scene: Scene
    private lateinit var filamentView: View
    private lateinit var camera: Camera
    private var cameraEntity = 0
    private var swapChain: SwapChain? = null
    private var skybox: Skybox? = null
    private var indirectLight: IndirectLight? = null

    private val entities = mutableListOf<Int>()
    private val vertexBuffers = mutableListOf<VertexBuffer>()
    private val indexBuffers = mutableListOf<IndexBuffer>()
    private val materials = mutableListOf<Material>()
    private val materialInstances = mutableListOf<MaterialInstance>()
    private val textures = mutableListOf<Texture>()
    private val clouds = mutableListOf<Cloud>()

    private var initialized = false
    private var sceneReady = false
    private var failed = false
    private var destroyed = false
    private var surfaceAttached = false
    private var paused = false
    private var activityPaused = false
    private var profile = initialProfile
    private var quality = initialQuality
    private var atmosphereMode = initialAtmosphereMode
    private var lastFrameNanos = 0L
    private var renderedFrames = 0L
    private var beginFrameRejectCount = 0L
    private var swapChainRecreations = 0
    private var releaseCount = 0
    private var lastError: String? = null
    private var parallaxX = 0f
    private var parallaxY = 0f
    private var cameraInputCount = 0L
    private var lastFrameDurationMs = 0L
    private var cameraEyeX = 0.0
    private var cameraEyeY = 0.0
    private var cameraEyeZ = 0.0

    init {
        textureView.contentDescription = "ORBIT native PBR landscape"
        textureView.isOpaque = true
        textureView.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN || event.action == MotionEvent.ACTION_MOVE) {
                parallaxX = (((event.x / max(1, textureView.width)) - 0.5f) * 1.6f).coerceIn(-1.5f, 1.5f)
                parallaxY = (((event.y / max(1, textureView.height)) - 0.5f) * 0.8f).coerceIn(-1.0f, 1.0f)
                cameraInputCount++
                Log.i("ORBIT_FILAMENT", "cameraInput=$cameraInputCount x=$parallaxX y=$parallaxY")
                if (::uiHelper.isInitialized && uiHelper.isReadyToRender && swapChain != null) {
                    renderFrame(System.nanoTime(), force = true)
                }
            }
            false
        }
        try {
            setupFilament()
            initialized = true
            setupSurface()
            buildScene()
        } catch (error: Throwable) {
            fail(error)
        }
    }

    override fun getView(): android.view.View = textureView

    override fun dispose() = release()

    private fun setupFilament() {
        ensureFilamentInitialized()
        engine = Engine.Builder()
            .featureLevel(Engine.FeatureLevel.FEATURE_LEVEL_1)
            .build()
        renderer = engine.createRenderer()
        scene = engine.createScene()
        filamentView = engine.createView()
        cameraEntity = engine.entityManager.create()
        camera = engine.createCamera(cameraEntity)
        filamentView.camera = camera
        filamentView.scene = scene
        filamentView.toneMapping = View.ToneMapping.ACES
        filamentView.dithering = View.Dithering.TEMPORAL
        filamentView.antiAliasing = View.AntiAliasing.FXAA
        frameScheduler = FrameCallback()
        frameScheduler.setRenderer(renderer)
    }

    private fun setupSurface() {
        displayHelper = DisplayHelper(activity)
        uiHelper = UiHelper(UiHelper.ContextErrorPolicy.DONT_CHECK)
        uiHelper.renderCallback = SurfaceCallback()
        uiHelper.attachTo(textureView)
        surfaceAttached = true
    }

    fun signalFailure(message: String) {
        lastError = message
        failed = true
        if (::frameScheduler.isInitialized) frameScheduler.remove()
        mainHandler.post {
            viewChannel.invokeMethod(
                "onError",
                mapOf("id" to viewId, "message" to message),
            )
        }
    }

    private fun fail(error: Throwable) {
        val message = error.message ?: error.javaClass.simpleName
        Log.e(TAG, "Filament failure in view $viewId", error)
        signalFailure(message)
    }

    @Synchronized
    fun setParallax(x: Float, y: Float) {
        if (destroyed || failed) return
        parallaxX = x.coerceIn(-1.5f, 1.5f)
        parallaxY = y.coerceIn(-1.0f, 1.0f)
        cameraInputCount++
        Log.i("ORBIT_FILAMENT", "cameraInput=$cameraInputCount x=$parallaxX y=$parallaxY")
        if (::uiHelper.isInitialized && uiHelper.isReadyToRender && swapChain != null) {
            renderFrame(System.nanoTime(), force = true)
        }
    }

    @Synchronized
    fun configure(
        profile: String,
        quality: String,
        paused: Boolean,
        atmosphereMode: String = "automatic",
    ) {
        if (destroyed || !initialized || failed) return
        try {
            val rebuild = profile != this.profile ||
                quality != this.quality ||
                atmosphereMode != this.atmosphereMode
            this.profile = profile
            this.quality = quality
            this.paused = paused
            this.atmosphereMode = atmosphereMode
            if (rebuild) buildScene()
            syncFrameScheduler()
        } catch (error: Throwable) {
            fail(error)
        }
    }

    @Synchronized
    fun setActivityPaused(value: Boolean) {
        if (destroyed || !initialized || failed) return
        activityPaused = value
        syncFrameScheduler()
    }

    @Synchronized
    fun release() {
        if (destroyed) return
        destroyed = true
        releaseCount++
        FilamentViewRegistry.unregister(viewId)
        if (::frameScheduler.isInitialized) frameScheduler.remove()
        if (surfaceAttached && ::uiHelper.isInitialized) {
            uiHelper.detach()
            surfaceAttached = false
        }
        if (!::engine.isInitialized) return
        if (::scene.isInitialized) destroySceneResources()
        swapChain?.let {
            engine.destroySwapChain(it)
            swapChain = null
        }
        engine.flushAndWait()
        if (::renderer.isInitialized) engine.destroyRenderer(renderer)
        if (::filamentView.isInitialized) engine.destroyView(filamentView)
        if (::scene.isInitialized) engine.destroyScene(scene)
        if (::camera.isInitialized) engine.destroyCameraComponent(camera.entity)
        if (cameraEntity != 0) engine.entityManager.destroy(cameraEntity)
        engine.destroy()
        initialized = false
    }

    fun stats(): Map<String, Any?> = mapOf(
        "profile" to profile,
        "quality" to quality,
        "atmosphereMode" to atmosphereMode,
        "initialized" to initialized,
        "sceneReady" to sceneReady,
        "paused" to (paused || activityPaused),
        "hasSwapChain" to (swapChain != null),
        "renderedFrames" to renderedFrames,
        "beginFrameRejectCount" to beginFrameRejectCount,
        "swapChainRecreations" to swapChainRecreations,
        "releaseCount" to releaseCount,
        "cameraInputCount" to cameraInputCount,
        "parallaxX" to parallaxX,
        "parallaxY" to parallaxY,
        "cameraEyeX" to cameraEyeX,
        "cameraEyeY" to cameraEyeY,
        "cameraEyeZ" to cameraEyeZ,
        "surfaceWidth" to textureView.width,
        "surfaceHeight" to textureView.height,
        "clearColorX" to renderer.clearOptions.clearColorX,
        "lastFrameDurationMs" to lastFrameDurationMs,
        "lastError" to lastError,
        "physicalPerformanceMeasured" to false,
    )

    private fun syncFrameScheduler() {
        if (destroyed || !initialized || failed || !::frameScheduler.isInitialized) return
        frameScheduler.remove()
        if (!paused && !activityPaused && quality != "static") frameScheduler.post()
        if (quality == "static" && !paused && !activityPaused) {
            renderFrame(System.nanoTime(), force = true)
        }
    }

    private fun buildScene() {
        destroySceneResources()
        val colors = SceneColors.forProfileAndAtmosphere(profile, atmosphereMode)
        renderer.clearOptions = Renderer.ClearOptions().apply {
            clear = true
            discard = true
            setClearColor(
                colors.sky[0].toDouble(),
                colors.sky[1].toDouble(),
                colors.sky[2].toDouble(),
                1.0,
            )
        }
        skybox = Skybox.Builder()
            .color(colors.sky[0], colors.sky[1], colors.sky[2], 1f)
            .build(engine)
        scene.skybox = skybox

        // Ambient irradiance keeps PBR shadow sides readable without an external HDR asset.
        indirectLight = IndirectLight.Builder()
            .irradiance(3, colors.ambient)
            .intensity(1.0f)
            .build(engine)
        scene.indirectLight = indirectLight

        val pbr = loadMaterial("materials/orbit_pbr.filamat")
        val atmosphere = loadMaterial("materials/orbit_unlit.filamat")
        val diffuse = loadTexture("photoreal/rocks_diffuse.jpg", srgb = true)
        val normal = loadTexture("photoreal/rocks_normal.jpg", srgb = false)
        val roughnessTexture = loadTexture("photoreal/rocks_roughness.jpg", srgb = false)
        val terrainResolution = if (quality == "ultra") 160 else 112
        val profileSeed = when (profile) {
            "atelier" -> 29
            "flow" -> 47
            "zen" -> 61
            else -> 3
        }
        val nearTerrain = createTerrainMesh(terrainResolution, seed = profileSeed)
        val farTerrain = createTerrainMesh(
            if (quality == "ultra") 112 else 80,
            seed = profileSeed + 14,
        )
        val sphere = createSphereMesh(
            segments = if (quality == "ultra") 32 else 24,
            rings = if (quality == "ultra") 20 else 14,
        )

        val nearMaterial = createPbrInstance(
            pbr, diffuse, normal, roughnessTexture,
            floatArrayOf(0.78f, 0.82f, 0.88f), 0.92f, 0.02f,
        )
        val farMaterial = createPbrInstance(
            pbr, diffuse, normal, roughnessTexture,
            floatArrayOf(0.56f, 0.60f, 0.68f), 0.98f, 0f,
        )

        val near = createRenderable(nearTerrain, nearMaterial)
        val nearHeight = when (profile) {
            "atelier" -> 1.36f
            "zen" -> 0.82f
            "flow" -> 1.16f
            else -> 1.08f
        }
        setTransform(near, 0f, -0.72f, 0f, 1f, nearHeight, 1f)
        val far = createRenderable(farTerrain, farMaterial)
        setTransform(far, -2f, 0.05f, -19f, 1.75f, 1.42f, 1.5f)

        if (profile != "flow") {
            val lake = createPlaneMesh()
            val waterMaterial = createPbrInstance(
                pbr, diffuse, normal, roughnessTexture,
                floatArrayOf(0.3f, 0.42f, 0.55f),
                if (profile == "zen") 0.34f else 0.24f,
                0.32f,
            )
            val water = createRenderable(lake, waterMaterial)
            setTransform(water, 0f, -0.48f, -4f, 1f, 1f, 1f)
        }

        val sunMaterial = atmosphere.createInstance().also {
            it.setParameter(
                "baseColor",
                colors.sun[0] * colors.sun[3],
                colors.sun[1] * colors.sun[3],
                colors.sun[2] * colors.sun[3],
                colors.sun[3],
            )
            materialInstances += it
        }
        val sun = createRenderable(sphere, sunMaterial, sphereBounds = true)
        val sunX = if (profile == "zen") 3.8f else -4.4f
        val sunY = if (profile == "atelier") 4.9f else 5.6f
        setTransform(sun, sunX, sunY, -19f, 0.72f, 0.72f, 0.72f)

        // Overlapping, differently scaled puffs read as cloud banks rather than
        // three isolated spheres. Balanced keeps the same geometry at its native cap.
        val cloudLayout = listOf(
            Cloud(0, -7.0f, 4.5f, -14f, 1.8f, 0.34f, 0.65f, 0.10f),
            Cloud(0, -5.5f, 4.65f, -14.2f, 2.2f, 0.46f, 0.72f, 0.10f),
            Cloud(0, -3.8f, 4.45f, -14f, 1.6f, 0.30f, 0.58f, 0.10f),
            Cloud(0, 0.0f, 5.35f, -19f, 2.3f, 0.38f, 0.75f, 0.065f),
            Cloud(0, 1.9f, 5.55f, -19.3f, 2.8f, 0.52f, 0.82f, 0.065f),
            Cloud(0, 4.1f, 5.3f, -19f, 2.0f, 0.34f, 0.64f, 0.065f),
            Cloud(0, 5.1f, 3.75f, -11f, 1.3f, 0.26f, 0.5f, 0.13f),
            Cloud(0, 6.2f, 3.9f, -11.2f, 1.7f, 0.35f, 0.58f, 0.13f),
            Cloud(0, 7.6f, 3.72f, -11f, 1.2f, 0.24f, 0.45f, 0.13f),
        )
        for ((index, cloud) in cloudLayout.withIndex()) {
            val instance = atmosphere.createInstance().also {
                val alpha = if (quality == "ultra") 0.24f else 0.18f
                it.setParameter(
                    "baseColor",
                    colors.cloud[0] * alpha,
                    colors.cloud[1] * alpha,
                    colors.cloud[2] * alpha,
                    alpha,
                )
                materialInstances += it
            }
            val entity = createRenderable(sphere, instance, sphereBounds = true)
            clouds += cloud.copy(entity = entity, phase = index * 1.7f)
        }

        createSunLight(colors)
        sceneReady = true
        updateCamera(0.0)
        renderFrame(System.nanoTime(), force = true)
    }

    private fun createSunLight(colors: SceneColors) {
        @Entity val light = EntityManager.get().create()
        entities += light
        LightManager.Builder(LightManager.Type.SUN)
            .color(colors.light[0], colors.light[1], colors.light[2])
            .intensity(92000f)
            .direction(-0.42f, -0.88f, -0.34f)
            .castShadows(false)
            .build(engine, light)
        scene.addEntity(light)
    }

    private fun loadTexture(path: String, srgb: Boolean): Texture {
        val bitmap = activity.assets.open(path).use { BitmapFactory.decodeStream(it) }
        val levels = 33 - Integer.numberOfLeadingZeros(maxOf(bitmap.width, bitmap.height))
        val texture = Texture.Builder()
            .width(bitmap.width)
            .height(bitmap.height)
            .levels(levels)
            .usage(Texture.Usage.DEFAULT or Texture.Usage.GEN_MIPMAPPABLE)
            .format(if (srgb) Texture.InternalFormat.SRGB8_A8 else Texture.InternalFormat.RGBA8)
            .build(engine)
        textures += texture
        val pixels = ByteBuffer.allocateDirect(bitmap.byteCount).order(ByteOrder.nativeOrder())
        bitmap.copyPixelsToBuffer(pixels)
        pixels.rewind()
        texture.setImage(
            engine,
            0,
            Texture.PixelBufferDescriptor(pixels, Texture.Format.RGBA, Texture.Type.UBYTE),
        )
        texture.generateMipmaps(engine)
        bitmap.recycle()
        return texture
    }

    private fun createPbrInstance(
        material: Material,
        diffuse: Texture,
        normal: Texture,
        roughnessTexture: Texture,
        color: FloatArray,
        roughness: Float,
        metallic: Float,
    ): MaterialInstance = material.createInstance().also {
        it.setParameter("baseColor", color[0], color[1], color[2])
        it.setParameter("roughness", roughness)
        it.setParameter("metallic", metallic)
        it.setParameter("baseColorMap", diffuse, com.google.android.filament.TextureSampler())
        it.setParameter("normalMap", normal, com.google.android.filament.TextureSampler())
        it.setParameter("roughnessMap", roughnessTexture, com.google.android.filament.TextureSampler())
        materialInstances += it
    }

    private fun loadMaterial(path: String): Material {
        val bytes = activity.assets.open(path).use { it.readBytes() }
        val buffer = ByteBuffer.allocateDirect(bytes.size)
            .order(ByteOrder.nativeOrder())
            .put(bytes)
            .apply { rewind() }
        return Material.Builder().payload(buffer, bytes.size).build(engine).also {
            materials += it
        }
    }

    private fun createRenderable(
        mesh: Mesh,
        material: MaterialInstance,
        sphereBounds: Boolean = false,
    ): Int {
        @Entity val entity = EntityManager.get().create()
        entities += entity
        val bounds = if (sphereBounds) {
            Box(0f, 0f, 0f, 1.1f, 1.1f, 1.1f)
        } else {
            Box(0f, 0f, -7f, 14f, 5f, 15f)
        }
        RenderableManager.Builder(1)
            .boundingBox(bounds)
            .geometry(
                0,
                RenderableManager.PrimitiveType.TRIANGLES,
                mesh.vertices,
                mesh.indices,
                0,
                mesh.indexCount,
            )
            .material(0, material)
            .build(engine, entity)
        scene.addEntity(entity)
        return entity
    }

    private fun createTerrainMesh(resolution: Int, seed: Int): Mesh {
        val side = resolution + 1
        val vertexCount = side * side
        val stride = 9 * 4 // position + quaternion tangent frame + UV
        val data = ByteBuffer.allocateDirect(vertexCount * stride)
            .order(ByteOrder.nativeOrder())

        fun hash(x: Int, z: Int): Float {
            val value = sin(x * 127.1 + z * 311.7 + seed * 74.7) * 43758.5453
            return (value - kotlin.math.floor(value)).toFloat()
        }
        fun noise(x: Float, z: Float): Float {
            val left = kotlin.math.floor(x).toInt()
            val back = kotlin.math.floor(z).toInt()
            val tx = x - left
            val tz = z - back
            val sx = tx * tx * (3f - 2f * tx)
            val sz = tz * tz * (3f - 2f * tz)
            val a = hash(left, back) * (1f - sx) + hash(left + 1, back) * sx
            val b = hash(left, back + 1) * (1f - sx) + hash(left + 1, back + 1) * sx
            return a * (1f - sz) + b * sz
        }
        fun height(x: Float, z: Float): Float {
            val broad = noise(x * 0.16f, z * 0.16f) * 2.1f
            val ridgeNoise = noise(x * 0.36f + 8f, z * 0.24f - 3f)
            val ridge = (1f - kotlin.math.abs(ridgeNoise * 2f - 1f)) * 1.5f
            val detail = noise(x * 1.1f, z * 0.9f) * 0.34f
            val fine = noise(x * 2.4f, z * 2.1f) * 0.11f
            val shoreline = 0.28f + 0.16f * sin(x * 0.34f + z * 0.2f)
            return broad + ridge + detail + fine + shoreline - 1.1f
        }

        for (zIndex in 0..resolution) {
            val z = -24f + 30f * zIndex / resolution
            for (xIndex in 0..resolution) {
                val x = -22f + 44f * xIndex / resolution
                val y = height(x, z)
                val epsilon = 0.04f
                val dhdx = (height(x + epsilon, z) - height(x - epsilon, z)) / (2 * epsilon)
                val dhdz = (height(x, z + epsilon) - height(x, z - epsilon)) / (2 * epsilon)
                val normal = normalize(floatArrayOf(-dhdx, 1f, -dhdz))
                val tangent = normalize(floatArrayOf(1f, dhdx, 0f))
                val bitangent = cross(normal, tangent)
                val frame = tangentFrameQuaternion(tangent, bitangent, normal)
                data.putFloat(x).putFloat(y).putFloat(z)
                data.putFloat(frame[0]).putFloat(frame[1]).putFloat(frame[2]).putFloat(frame[3])
                data.putFloat((x + 22f) / 6f).putFloat((z + 24f) / 6f)
            }
        }
        data.rewind()
        val vertices = VertexBuffer.Builder()
            .bufferCount(1)
            .vertexCount(vertexCount)
            .attribute(
                VertexBuffer.VertexAttribute.POSITION,
                0,
                VertexBuffer.AttributeType.FLOAT3,
                0,
                stride,
            )
            .attribute(
                VertexBuffer.VertexAttribute.TANGENTS,
                0,
                VertexBuffer.AttributeType.FLOAT4,
                12,
                stride,
            )
            .attribute(
                VertexBuffer.VertexAttribute.UV0,
                0,
                VertexBuffer.AttributeType.FLOAT2,
                28,
                stride,
            )
            .build(engine)
        vertexBuffers += vertices
        vertices.setBufferAt(engine, 0, data)

        val indexCount = resolution * resolution * 6
        val indices = ByteBuffer.allocateDirect(indexCount * 4)
            .order(ByteOrder.nativeOrder())
        for (z in 0 until resolution) {
            for (x in 0 until resolution) {
                val a = z * side + x
                val b = a + 1
                val c = a + side
                val d = c + 1
                indices.putInt(a).putInt(c).putInt(b)
                indices.putInt(b).putInt(c).putInt(d)
            }
        }
        indices.rewind()
        val indexBuffer = IndexBuffer.Builder()
            .indexCount(indexCount)
            .bufferType(IndexBuffer.Builder.IndexType.UINT)
            .build(engine)
        indexBuffers += indexBuffer
        indexBuffer.setBuffer(engine, indices)
        return Mesh(vertices, indexBuffer, indexCount)
    }

    private fun createPlaneMesh(): Mesh {
        val frame = tangentFrameQuaternion(
            floatArrayOf(1f, 0f, 0f),
            floatArrayOf(0f, 0f, -1f),
            floatArrayOf(0f, 1f, 0f),
        )
        val data = ByteBuffer.allocateDirect(4 * 9 * 4).order(ByteOrder.nativeOrder())
        val positions = floatArrayOf(
            -13f, 0f, -20f,
            13f, 0f, -20f,
            -13f, 0f, 4f,
            13f, 0f, 4f,
        )
        val uvs = floatArrayOf(0f, 0f, 4f, 0f, 0f, 4f, 4f, 4f)
        for (vertex in 0 until 4) {
            data.putFloat(positions[vertex * 3])
            data.putFloat(positions[vertex * 3 + 1])
            data.putFloat(positions[vertex * 3 + 2])
            frame.forEach { data.putFloat(it) }
            data.putFloat(uvs[vertex * 2]).putFloat(uvs[vertex * 2 + 1])
        }
        data.rewind()
        val vertices = VertexBuffer.Builder()
            .bufferCount(1)
            .vertexCount(4)
            .attribute(VertexBuffer.VertexAttribute.POSITION, 0, VertexBuffer.AttributeType.FLOAT3, 0, 36)
            .attribute(VertexBuffer.VertexAttribute.TANGENTS, 0, VertexBuffer.AttributeType.FLOAT4, 12, 36)
            .attribute(VertexBuffer.VertexAttribute.UV0, 0, VertexBuffer.AttributeType.FLOAT2, 28, 36)
            .build(engine)
        vertexBuffers += vertices
        vertices.setBufferAt(engine, 0, data)
        val indices = ByteBuffer.allocateDirect(6 * 4).order(ByteOrder.nativeOrder())
        indices.putInt(0).putInt(2).putInt(1).putInt(1).putInt(2).putInt(3)
        indices.rewind()
        val indexBuffer = IndexBuffer.Builder()
            .indexCount(6)
            .bufferType(IndexBuffer.Builder.IndexType.UINT)
            .build(engine)
        indexBuffers += indexBuffer
        indexBuffer.setBuffer(engine, indices)
        return Mesh(vertices, indexBuffer, 6)
    }

    private fun createSphereMesh(segments: Int, rings: Int): Mesh {
        val vertexCount = (segments + 1) * (rings + 1)
        val data = ByteBuffer.allocateDirect(vertexCount * 3 * 4)
            .order(ByteOrder.nativeOrder())
        for (ring in 0..rings) {
            val phi = PI * ring / rings
            val y = cos(phi).toFloat()
            val radius = sin(phi).toFloat()
            for (segment in 0..segments) {
                val theta = 2 * PI * segment / segments
                data.putFloat((radius * cos(theta)).toFloat())
                data.putFloat(y)
                data.putFloat((radius * sin(theta)).toFloat())
            }
        }
        data.rewind()
        val vertices = VertexBuffer.Builder()
            .bufferCount(1)
            .vertexCount(vertexCount)
            .attribute(
                VertexBuffer.VertexAttribute.POSITION,
                0,
                VertexBuffer.AttributeType.FLOAT3,
                0,
                12,
            )
            .build(engine)
        vertexBuffers += vertices
        vertices.setBufferAt(engine, 0, data)

        val indexCount = segments * rings * 6
        val indices = ByteBuffer.allocateDirect(indexCount * 4)
            .order(ByteOrder.nativeOrder())
        for (ring in 0 until rings) {
            for (segment in 0 until segments) {
                val a = ring * (segments + 1) + segment
                val b = a + segments + 1
                indices.putInt(a).putInt(b).putInt(a + 1)
                indices.putInt(a + 1).putInt(b).putInt(b + 1)
            }
        }
        indices.rewind()
        val indexBuffer = IndexBuffer.Builder()
            .indexCount(indexCount)
            .bufferType(IndexBuffer.Builder.IndexType.UINT)
            .build(engine)
        indexBuffers += indexBuffer
        indexBuffer.setBuffer(engine, indices)
        return Mesh(vertices, indexBuffer, indexCount)
    }

    private fun destroySceneResources() {
        if (!sceneReady && entities.isEmpty() && vertexBuffers.isEmpty() &&
            materialInstances.isEmpty() && materials.isEmpty() && textures.isEmpty() &&
            skybox == null && indirectLight == null
        ) return
        if (::frameScheduler.isInitialized) frameScheduler.remove()
        scene.skybox = null
        scene.indirectLight = null
        for (entity in entities) {
            scene.remove(entity)
            engine.destroyEntity(entity)
            EntityManager.get().destroy(entity)
        }
        entities.clear()
        clouds.clear()
        materialInstances.forEach { engine.destroyMaterialInstance(it) }
        materialInstances.clear()
        vertexBuffers.forEach { engine.destroyVertexBuffer(it) }
        vertexBuffers.clear()
        indexBuffers.forEach { engine.destroyIndexBuffer(it) }
        indexBuffers.clear()
        materials.forEach { engine.destroyMaterial(it) }
        materials.clear()
        textures.forEach { engine.destroyTexture(it) }
        textures.clear()
        skybox?.let { engine.destroySkybox(it) }
        skybox = null
        indirectLight?.let { engine.destroyIndirectLight(it) }
        indirectLight = null
        sceneReady = false
        engine.flushAndWait()
    }

    private fun updateCamera(seconds: Double) {
        val motion = if (quality == "ultra") 1.0f else 0.7f
        // Clamp parallax inputs to safe framing bounds to prevent viewport edge clipping and black bands
        val safeParallaxX = parallaxX.coerceIn(-0.65f, 0.65f)
        val safeParallaxY = parallaxY.coerceIn(-0.5f, 0.5f)
        val eyeX = sin(seconds * 0.45) * 0.75 * motion + safeParallaxX * 1.1
        val eyeY = 3.8 + sin(seconds * 0.31) * 0.22 * motion - safeParallaxY * 0.75
        val eyeZ = 8.7 + cos(seconds * 0.25) * 0.45 * motion
        cameraEyeX = eyeX
        cameraEyeY = eyeY
        cameraEyeZ = eyeZ
        camera.lookAt(
            eyeX,
            eyeY,
            eyeZ,
            safeParallaxX * 0.45,
            1.25 - safeParallaxY * 0.25,
            -5.5,
            0.0,
            1.0,
            0.0,
        )
        for (cloud in clouds) {
            val drift = (sin(seconds * cloud.speed * 3 + cloud.phase) * 1.8f).toFloat()
            setTransform(
                cloud.entity,
                cloud.x + drift,
                cloud.y,
                cloud.z,
                cloud.scaleX,
                cloud.scaleY,
                cloud.scaleZ,
            )
        }
    }

    private fun renderFrame(frameTimeNanos: Long, force: Boolean = false) {
        try {
            renderFrameUnsafe(frameTimeNanos, force)
        } catch (error: Throwable) {
            fail(error)
        }
    }

    private fun renderFrameUnsafe(frameTimeNanos: Long, force: Boolean = false) {
        if (destroyed || !initialized || failed || !sceneReady || paused || activityPaused) return
        if (!uiHelper.isReadyToRender) return
        val chain = swapChain ?: return
        val width = textureView.width
        val height = textureView.height
        if (width > 0 && height > 0) {
            val vp = filamentView.viewport
            if (vp.width != width || vp.height != height) {
                filamentView.viewport = Viewport(0, 0, width, height)
                camera.setProjection(
                    46.0,
                    width.toDouble() / height.toDouble(),
                    0.1,
                    100.0,
                    Camera.Fov.VERTICAL,
                )
            }
        }
        val interval = if (quality == "balanced") 66_666_666L else 33_333_333L
        if (!force && frameTimeNanos - lastFrameNanos < interval) return
        lastFrameNanos = frameTimeNanos
        updateCamera(frameTimeNanos / 1_000_000_000.0)
        val frameStartedAt = android.os.SystemClock.elapsedRealtime()
        if (renderer.beginFrame(chain, frameTimeNanos)) {
            renderer.render(filamentView)
            renderer.endFrame()
            lastFrameDurationMs = android.os.SystemClock.elapsedRealtime() - frameStartedAt
            renderedFrames++
        } else {
            beginFrameRejectCount++
        }
    }

    private fun setTransform(
        entity: Int,
        tx: Float,
        ty: Float,
        tz: Float,
        sx: Float,
        sy: Float,
        sz: Float,
    ) {
        val matrix = FloatArray(16)
        Matrix.setIdentityM(matrix, 0)
        Matrix.translateM(matrix, 0, tx, ty, tz)
        Matrix.scaleM(matrix, 0, sx, sy, sz)
        val manager = engine.transformManager
        manager.setTransform(manager.getInstance(entity), matrix)
    }

    inner class FrameCallback : ChoreographerHelper() {
        override fun onFrame(frameTimeNanos: Long) = renderFrame(frameTimeNanos)
    }

    inner class SurfaceCallback : UiHelper.RendererCallback {
        override fun onNativeWindowChanged(surface: Surface) {
            try {
                if (destroyed || !initialized || failed) return
                swapChain?.let { engine.destroySwapChain(it) }
                var flags = uiHelper.swapChainFlags
                if (SwapChain.isSRGBSwapChainSupported(engine)) {
                    flags = flags or SwapChainFlags.CONFIG_SRGB_COLORSPACE
                }
                swapChain = engine.createSwapChain(surface, flags)
                swapChainRecreations++
                displayHelper.attach(renderer, textureView.display)
                renderFrame(System.nanoTime(), force = true)
            } catch (error: Throwable) {
                fail(error)
            }
        }

        override fun onDetachedFromSurface() {
            try {
                if (!initialized) return
                displayHelper.detach()
                swapChain?.let {
                    engine.destroySwapChain(it)
                    engine.flushAndWait()
                    swapChain = null
                }
            } catch (error: Throwable) {
                fail(error)
            }
        }

        override fun onResized(width: Int, height: Int) {
            try {
                if (destroyed || !initialized || failed || width == 0 || height == 0) return
                filamentView.viewport = Viewport(0, 0, width, height)
                camera.setProjection(
                    46.0,
                    width.toDouble() / height.toDouble(),
                    0.1,
                    100.0,
                    Camera.Fov.VERTICAL,
                )
                FilamentHelper.synchronizePendingFrames(engine)
                renderFrame(System.nanoTime(), force = true)
            } catch (error: Throwable) {
                fail(error)
            }
        }
    }

    private data class Mesh(
        val vertices: VertexBuffer,
        val indices: IndexBuffer,
        val indexCount: Int,
    )

    private data class Cloud(
        val entity: Int,
        val x: Float,
        val y: Float,
        val z: Float,
        val scaleX: Float,
        val scaleY: Float,
        val scaleZ: Float,
        val speed: Float,
        val phase: Float = 0f,
    )

    private data class SceneColors(
        val sky: FloatArray,
        val near: FloatArray,
        val far: FloatArray,
        val sun: FloatArray,
        val cloud: FloatArray,
        val light: FloatArray,
        val ambient: FloatArray,
    ) {
        companion object {
            fun forProfileAndAtmosphere(profile: String, atmosphere: String): SceneColors {
                val effectiveMode = if (atmosphere == "automatic") {
                    val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
                    when {
                        hour in 5..8 -> "dawn"
                        hour in 9..17 -> "day"
                        hour in 18..21 -> "sunset"
                        else -> "night"
                    }
                } else atmosphere.lowercase()

                return when (effectiveMode) {
                    "dawn" -> SceneColors(
                        sky = floatArrayOf(0.42f, 0.28f, 0.38f),
                        near = floatArrayOf(0.24f, 0.18f, 0.22f),
                        far = floatArrayOf(0.55f, 0.34f, 0.36f),
                        sun = floatArrayOf(1.0f, 0.78f, 0.45f, 1f),
                        cloud = floatArrayOf(0.92f, 0.65f, 0.60f),
                        light = floatArrayOf(1.0f, 0.82f, 0.60f),
                        ambient = floatArrayOf(0.35f, 0.25f, 0.30f),
                    )
                    "day" -> SceneColors(
                        sky = floatArrayOf(0.24f, 0.48f, 0.82f),
                        near = floatArrayOf(0.32f, 0.38f, 0.40f),
                        far = floatArrayOf(0.42f, 0.54f, 0.68f),
                        sun = floatArrayOf(1.0f, 0.98f, 0.92f, 1f),
                        cloud = floatArrayOf(0.95f, 0.96f, 1.0f),
                        light = floatArrayOf(1.0f, 0.97f, 0.90f),
                        ambient = floatArrayOf(0.45f, 0.52f, 0.65f),
                    )
                    "sunset" -> SceneColors(
                        sky = floatArrayOf(0.35f, 0.14f, 0.25f),
                        near = floatArrayOf(0.18f, 0.10f, 0.16f),
                        far = floatArrayOf(0.62f, 0.24f, 0.22f),
                        sun = floatArrayOf(1.0f, 0.45f, 0.18f, 1f),
                        cloud = floatArrayOf(0.95f, 0.42f, 0.32f),
                        light = floatArrayOf(1.0f, 0.52f, 0.28f),
                        ambient = floatArrayOf(0.28f, 0.15f, 0.22f),
                    )
                    "night" -> SceneColors(
                        sky = floatArrayOf(0.015f, 0.02f, 0.06f),
                        near = floatArrayOf(0.04f, 0.045f, 0.09f),
                        far = floatArrayOf(0.08f, 0.10f, 0.18f),
                        sun = floatArrayOf(0.72f, 0.82f, 1.0f, 0.65f),
                        cloud = floatArrayOf(0.25f, 0.30f, 0.45f),
                        light = floatArrayOf(0.45f, 0.55f, 0.80f),
                        ambient = floatArrayOf(0.06f, 0.08f, 0.14f),
                    )
                    else -> forProfile(profile)
                }
            }

            fun forProfile(profile: String): SceneColors = when (profile) {
                "atelier" -> SceneColors(
                    floatArrayOf(0.07f, 0.055f, 0.11f),
                    floatArrayOf(0.15f, 0.105f, 0.16f),
                    floatArrayOf(0.37f, 0.23f, 0.29f),
                    floatArrayOf(1f, 0.72f, 0.47f, 1f),
                    floatArrayOf(0.8f, 0.64f, 0.7f),
                    floatArrayOf(1f, 0.79f, 0.65f),
                    floatArrayOf(0.2f, 0.16f, 0.22f),
                )
                "flow" -> SceneColors(
                    floatArrayOf(0.055f, 0.05f, 0.16f),
                    floatArrayOf(0.105f, 0.1f, 0.22f),
                    floatArrayOf(0.31f, 0.24f, 0.47f),
                    floatArrayOf(1f, 0.62f, 0.48f, 1f),
                    floatArrayOf(0.58f, 0.72f, 0.9f),
                    floatArrayOf(0.72f, 0.82f, 1f),
                    floatArrayOf(0.15f, 0.18f, 0.3f),
                )
                "zen" -> SceneColors(
                    floatArrayOf(0.71f, 0.74f, 0.86f),
                    floatArrayOf(0.32f, 0.33f, 0.4f),
                    floatArrayOf(0.58f, 0.54f, 0.62f),
                    floatArrayOf(1f, 0.88f, 0.6f, 1f),
                    floatArrayOf(1f, 0.95f, 0.9f),
                    floatArrayOf(1f, 0.9f, 0.75f),
                    floatArrayOf(0.55f, 0.58f, 0.68f),
                )
                else -> SceneColors(
                    floatArrayOf(0.04f, 0.05f, 0.13f),
                    floatArrayOf(0.065f, 0.075f, 0.15f),
                    floatArrayOf(0.25f, 0.21f, 0.36f),
                    floatArrayOf(1f, 0.72f, 0.52f, 1f),
                    floatArrayOf(0.62f, 0.65f, 0.82f),
                    floatArrayOf(1f, 0.82f, 0.67f),
                    floatArrayOf(0.16f, 0.18f, 0.29f),
                )
            }
        }
    }

    companion object {
        private const val TAG = "OrbitFilament"
        private val runtimeLock = Any()
        private var runtimeInitialized = false

        /** Load native libraries only when a user actually opens the 3D renderer. */
        private fun ensureFilamentInitialized() {
            synchronized(runtimeLock) {
                if (!runtimeInitialized) {
                    Filament.init()
                    runtimeInitialized = true
                }
            }
        }

        private fun normalize(value: FloatArray): FloatArray {
            val length = sqrt(value[0] * value[0] + value[1] * value[1] + value[2] * value[2])
            return floatArrayOf(value[0] / length, value[1] / length, value[2] / length)
        }

        private fun cross(a: FloatArray, b: FloatArray): FloatArray = floatArrayOf(
            a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0],
        )

        /** Converts an orthonormal tangent/bitangent/normal basis to Filament's quaternion. */
        private fun tangentFrameQuaternion(
            tangent: FloatArray,
            bitangent: FloatArray,
            normal: FloatArray,
        ): FloatArray {
            val m00 = tangent[0]
            val m01 = bitangent[0]
            val m02 = normal[0]
            val m10 = tangent[1]
            val m11 = bitangent[1]
            val m12 = normal[1]
            val m20 = tangent[2]
            val m21 = bitangent[2]
            val m22 = normal[2]
            val trace = m00 + m11 + m22
            val x: Float
            val y: Float
            val z: Float
            val w: Float
            if (trace > 0f) {
                val s = sqrt(trace + 1f) * 2f
                w = 0.25f * s
                x = (m21 - m12) / s
                y = (m02 - m20) / s
                z = (m10 - m01) / s
            } else if (m00 > m11 && m00 > m22) {
                val s = sqrt(1f + m00 - m11 - m22) * 2f
                w = (m21 - m12) / s
                x = 0.25f * s
                y = (m01 + m10) / s
                z = (m02 + m20) / s
            } else if (m11 > m22) {
                val s = sqrt(1f + m11 - m00 - m22) * 2f
                w = (m02 - m20) / s
                x = (m01 + m10) / s
                y = 0.25f * s
                z = (m12 + m21) / s
            } else {
                val s = sqrt(1f + m22 - m00 - m11) * 2f
                w = (m10 - m01) / s
                x = (m02 + m20) / s
                y = (m12 + m21) / s
                z = 0.25f * s
            }
            return floatArrayOf(x, y, z, w)
        }
    }
}
