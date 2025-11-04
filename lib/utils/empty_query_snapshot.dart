import 'package:cloud_firestore/cloud_firestore.dart';

// Utility class to represent an empty QuerySnapshot in Firestore streams.
class EmptyQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => EmptySnapshotMetadata();

  @override
  int get size => 0;
}

class EmptySnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}