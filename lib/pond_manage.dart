import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class PondManagePage extends StatelessWidget {
  const PondManagePage({super.key});

  (String status, Color color) getPondHealth(AquaMonitorState state) {
    if (state.turbidityHistory.isEmpty ||
        state.temperatureHistory.isEmpty ||
        state.phHistory.isEmpty) {
      return ("No Data", Colors.grey);
    }

    final turb = state.turbidityHistory.last;
    final temp = state.temperatureHistory.last;
    final ph = state.phHistory.last;

    /// IDEAL RANGES (you can tweak)
    bool turbGood = turb < 10;
    bool tempGood = temp >= 24 && temp <= 30;
    bool phGood   = ph >= 6.5 && ph <= 8.5;

    int score = [turbGood, tempGood, phGood].where((e) => e).length;

    if (score == 3) return ("Good", Colors.green);
    if (score == 2) return ("Warning", Colors.orange);
    return ("Critical", Colors.red);
  }

  void showAddDialog(BuildContext context) {
    final name = TextEditingController();
    final fish = TextEditingController();
    final size = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E1628),
        title: const Text("Add Pond", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(name, "Pond Name"),
            _field(fish, "Fish Type"),
            _field(size, "Pond Size"),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              context.read<AquaMonitorState>().addPondFull(
                    name.text,
                    fish.text,
                    size.text,
                  );
              Navigator.pop(context);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  void showRenameDialog(BuildContext context, int index, String current) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E1628),
        title: const Text("Rename Pond", style: TextStyle(color: Colors.white)),
        content: _field(controller, "New Name"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              context.read<AquaMonitorState>().ponds[index].name =
                  controller.text;
              context.read<AquaMonitorState>().notifyListeners();
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AquaMonitorState>();

    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // 🔥 key fix
        child: FloatingActionButton(
          onPressed: () => showAddDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                10,
              ),
              child: const Text(
                "Pond Management",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final pond = state.ponds[i];

                  return GestureDetector(
                    onTap: () {
                      context.read<AquaMonitorState>().selectPond(i);
                    },
                    child: Builder(
                      builder: (context) {
                        final isSelected = state.selectedPondIndex == i;

                        final health = getPondHealth(state);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1628),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00D4FF)
                                  : Colors.white.withOpacity(0.08),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pond.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  /// 🟢 HEALTH BADGE
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: health.$2.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      health.$1,
                                      style: TextStyle(
                                        color: health.$2,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  /// ACTIVE LABEL
                                  if (isSelected)
                                    const Text(
                                      "ACTIVE",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("Fish: ${pond.fishType}",
                                  style: const TextStyle(color: Colors.white70)),
                              Text("Size: ${pond.pondSize}",
                                  style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () =>
                                        showRenameDialog(context, i, pond.name),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () =>
                                        context.read<AquaMonitorState>().deletePond(i),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: state.ponds.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}