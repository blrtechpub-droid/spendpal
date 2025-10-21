import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_home_screen.dart';
import 'package:spendpal/models/group_model.dart';

class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({Key? key}) : super(key: key);

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  String _selectedGroupType = "Trip"; // Default selected type
  bool _isGroupNameValid = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.addListener(() {
      setState(() {
        _isGroupNameValid = _groupNameController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

Future<void> _createGroup() async {
  if (_groupNameController.text.isEmpty) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  final newGroup = GroupModel(
    groupId: '', // Firestore will assign one
    type: _selectedGroupType,
    name: _groupNameController.text.trim(),
    createdBy: uid,
    members: [uid],
    createdAt: DateTime.now(),
    photo: '', // default empty or use default asset URL if needed
  );

  final groupRef = await FirebaseFirestore.instance.collection('groups').add(newGroup.toMap());

  // Optionally: update the group's ID field after creation
  await groupRef.update({'id': groupRef.id});

  // Create updated GroupModel with the actual groupId from Firestore
  final createdGroup = GroupModel(
    groupId: groupRef.id,
    type: newGroup.type,
    name: newGroup.name,
    createdBy: newGroup.createdBy,
    members: newGroup.members,
    createdAt: newGroup.createdAt,
    photo: newGroup.photo,
  );

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => GroupHomeScreen(group: createdGroup)),
  );
}

  Widget _buildGroupTypeButton(String label) {
    final isSelected = _selectedGroupType == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedGroupType = label;
        });
      },
      selectedColor: Colors.purple.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Create a group"),
        actions: [
          TextButton(
            onPressed: _isGroupNameValid ? _createGroup : null,
            child: Text(
              "Done",
              style: TextStyle(
                color: _isGroupNameValid ? Colors.tealAccent : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_outlined, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: "Group name",
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),
            const Text("Type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: ["Trip", "Home", "Couple", "Other"]
                  .map((type) => _buildGroupTypeButton(type))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }
}