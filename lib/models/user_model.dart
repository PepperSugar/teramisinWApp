class UserModel {
  final String uid;
  final String displayName;
  final String photoURL;
  final DateTime joinedAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.joinedAt,
  });

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    DateTime? joinedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String,
      photoURL: map['photoURL'] as String,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoURL': photoURL,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }
}
