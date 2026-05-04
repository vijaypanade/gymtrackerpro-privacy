import 'package:flutter/material.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final Map<String, dynamic> day;

  const WorkoutSessionScreen({super.key, required this.day});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {

  List<Map<String, dynamic>> sets = [];

  @override
  void initState() {
    super.initState();

    final exercises = widget.day['exercises'];

    for (var ex in exercises) {
      for (int i = 0; i < ex['sets']; i++) {
        sets.add({
          "name": ex['name'],
          "reps": 0,
          "done": false,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.day['focus'] ?? "Workout"),
      ),

      body: ListView.builder(
        itemCount: sets.length,
        itemBuilder: (_, i) {
          final s = sets[i];

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text(s['name']),
              subtitle: Text("Reps: ${s['reps']}"),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ➖
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        if (s['reps'] > 0) s['reps']--;
                      });
                    },
                  ),

                  // ➕
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        s['reps']++;
                      });
                    },
                  ),

                  // ✅ Done
                  IconButton(
                    icon: Icon(
                      s['done']
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: s['done'] ? Colors.green : null,
                    ),
                    onPressed: () {
                      setState(() {
                        s['done'] = !s['done'];
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),

      // 🔥 COMPLETE BUTTON
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("Finish Workout 💪"),
        ),
      ),
    );
  }
}