import 'package:flutter/material.dart';
import 'package:hrms_app/models/employee_model.dart';

class Assign_TASK_TO_LEAD_FORM extends StatefulWidget {
  final Employee lead;

  const Assign_TASK_TO_LEAD_FORM({super.key, required this.lead});

  @override
  State<Assign_TASK_TO_LEAD_FORM> createState() => _assign_task_formState();
}

class _assign_task_formState extends State<Assign_TASK_TO_LEAD_FORM> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Task to Lead')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigning task to: ${widget.lead.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
