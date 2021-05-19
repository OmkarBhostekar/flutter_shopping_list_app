import 'package:cloud_firestore/cloud_firestore.dart';

extension FirebaseFireStoreX on FirebaseFirestore {
  CollectionReference userListRef(String userId) =>
      collection('lists').doc(userId).collection('userList');
}
