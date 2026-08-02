/// The four roles that can take part in a chat, mirrored from the backend's
/// User / Vendor / Captain / admin (Tenant) actors.
enum ChatRole { user, vendor, captain, admin }

ChatRole chatRoleFromString(String value) {
  return ChatRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => ChatRole.user,
  );
}

/// Identifies "who is using the chat right now" — the role + the backend id
/// for that role (User.id / Vendor.id / Captain.id, or the tenant id for
/// admin). [participantId] is the flat string the backend also uses,
/// e.g. "user_42", "captain_7", "admin_SADAT".
class ChatParticipant {
  final ChatRole role;
  final String id;
  final String displayName;

  const ChatParticipant({
    required this.role,
    required this.id,
    required this.displayName,
  });

  String get participantId => '${role.name}_$id';

  factory ChatParticipant.admin({String tenantId = 'SADAT', String displayName = 'الدعم'}) =>
      ChatParticipant(role: ChatRole.admin, id: tenantId, displayName: displayName);
}
