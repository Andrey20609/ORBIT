import '../../data/database/orbit_data_engine.dart';
import '../../data/models/contact_record.dart';

final class ContactsService {
  ContactsService({required OrbitDataEngine dataEngine})
      : _dataEngine = dataEngine;

  final OrbitDataEngine _dataEngine;

  Future<List<ContactRecord>> getContacts({String? workspaceId}) async {
    return _dataEngine.getContacts(workspaceId: workspaceId);
  }

  Future<ContactRecord?> getContactById(String id, {String? workspaceId}) async {
    final contacts = await _dataEngine.getContacts(workspaceId: workspaceId);
    for (final c in contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<ContactRecord> createContact({
    required String name,
    required String email,
    String? phone,
    String? company,
    String? role,
    String? avatarUrl,
    String? workspaceId,
  }) async {
    final id = 'contact_${DateTime.now().millisecondsSinceEpoch}_${email.hashCode.abs()}';
    final contact = ContactRecord(
      id: id,
      workspaceId: workspaceId ?? _dataEngine.activeWorkspaceId,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone?.trim(),
      company: company?.trim(),
      role: role?.trim(),
      avatarUrl: avatarUrl,
    );

    await _dataEngine.saveContact(contact);
    return contact;
  }

  Future<void> updateContact(ContactRecord contact) async {
    await _dataEngine.saveContact(contact);
  }

  Future<void> deleteContact(String contactId) async {
    await _dataEngine.deleteContact(contactId);
  }

  Future<List<ContactRecord>> searchContacts(String query, {String? workspaceId}) async {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return getContacts(workspaceId: workspaceId);

    final contacts = await _dataEngine.getContacts(workspaceId: workspaceId);
    return contacts.where((c) {
      final matchesName = c.name.toLowerCase().contains(cleanQuery);
      final matchesEmail = c.email.toLowerCase().contains(cleanQuery);
      final matchesCompany = c.company?.toLowerCase().contains(cleanQuery) ?? false;
      final matchesRole = c.role?.toLowerCase().contains(cleanQuery) ?? false;
      final matchesPhone = c.phone?.toLowerCase().contains(cleanQuery) ?? false;
      return matchesName || matchesEmail || matchesCompany || matchesRole || matchesPhone;
    }).toList();
  }

  Future<Map<String, List<ContactRecord>>> getContactsGroupedByLetter({
    String? workspaceId,
  }) async {
    final contacts = await getContacts(workspaceId: workspaceId);
    final sorted = List<ContactRecord>.from(contacts)
      ..sort((a, b) => a.name.compareTo(b.name));

    final grouped = <String, List<ContactRecord>>{};
    for (final contact in sorted) {
      final letter = contact.name.isNotEmpty
          ? contact.name.substring(0, 1).toUpperCase()
          : '#';
      grouped.putIfAbsent(letter, () => []).add(contact);
    }
    return grouped;
  }
}
