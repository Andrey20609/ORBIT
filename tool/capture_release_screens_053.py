from __future__ import annotations

from pathlib import Path

import capture_release_screens_052 as screens
import capture_release_settings_052 as settings


def main() -> None:
    output = Path(__file__).resolve().parents[1] / "validation" / "orbit054"
    screens.ui.OUT = output
    settings.ui.OUT = output
    screens.main()
    settings.main()


if __name__ == "__main__":
    main()
