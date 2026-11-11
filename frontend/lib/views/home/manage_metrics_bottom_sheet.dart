import 'package:flutter/material.dart';
import '../../controllers/dashboard_preference_controller.dart';
import '../../models/dashboard_preference.dart';

class ManageMetricsBottomSheet extends StatefulWidget {
  const ManageMetricsBottomSheet({super.key, required this.controller, required this.profileId});
  final DashboardPreferenceController controller;
  final String profileId;

  static Future<bool?> show(BuildContext context, DashboardPreferenceController controller, String profileId) =>
      showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => ManageMetricsBottomSheet(controller: controller, profileId: profileId));

  @override
  State<ManageMetricsBottomSheet> createState() => _ManageMetricsBottomSheetState();
}

class _ManageMetricsBottomSheetState extends State<ManageMetricsBottomSheet> {
  late List<String> selected;
  late List<String> ordered;
  late List<String> displayOrder;

  @override
  void initState() {
    super.initState();
    final preference = widget.controller.preference;
    selected = List.of(preference?.selectedMetrics ?? DashboardPreference.defaults);
    ordered = List.of(preference?.metricOrder ?? selected);
    for (final code in selected) { if (!ordered.contains(code)) ordered.add(code); }
    displayOrder = [...ordered, ...MetricDefinition.all.map((m) => m.code).where((code) => !ordered.contains(code))];
  }

  void _toggle(String code, bool value) {
    setState(() {
      if (value) { if (!selected.contains(code)) selected.add(code); if (!ordered.contains(code)) ordered.add(code); }
      else { selected.remove(code); ordered.remove(code); }
      displayOrder = [...ordered, ...MetricDefinition.all.map((m) => m.code).where((item) => !ordered.contains(item))];
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(height: MediaQuery.sizeOf(context).height * .82,
      child: Column(children: [
        const SizedBox(height: 18),
        const Text('Quản lý chỉ số theo dõi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const Padding(padding: EdgeInsets.all(12), child: Text('Chọn chỉ số và kéo biểu tượng bên phải để đổi thứ tự.')),
        Expanded(child: ReorderableListView.builder(
          itemCount: MetricDefinition.all.length,
          onReorder: (oldIndex, newIndex) => setState(() {
            displayOrder = widget.controller.reorderMetrics(displayOrder, oldIndex, newIndex);
            final selectedOrder = displayOrder.where(selected.contains).toList();
            for (final code in selected) { if (!selectedOrder.contains(code)) selectedOrder.add(code); }
            ordered = selectedOrder;
          }),
          itemBuilder: (context, index) {
            final metric = MetricDefinition.byCode(displayOrder[index]);
            return CheckboxListTile(key: ValueKey(metric.code), value: selected.contains(metric.code),
              title: Text(metric.label), subtitle: Text(metric.unit), controlAffinity: ListTileControlAffinity.leading,
              secondary: const Icon(Icons.drag_handle), onChanged: (value) => _toggle(metric.code, value ?? false));
          },
        )),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Row(children: [
          TextButton(onPressed: () => setState(() { selected = List.of(DashboardPreference.defaults); ordered = List.of(DashboardPreference.defaults); displayOrder = [...ordered, ...MetricDefinition.all.map((m) => m.code).where((code) => !ordered.contains(code))]; }), child: const Text('Khôi phục mặc định')),
          const Spacer(),
          FilledButton(onPressed: widget.controller.saving ? null : () async {
            final finalOrder = ordered.where(selected.contains).toList();
            for (final code in selected) { if (!finalOrder.contains(code)) finalOrder.add(code); }
            final success = await widget.controller.savePreference(selected, finalOrder);
            if (context.mounted && success) Navigator.pop(context, true);
          }, child: widget.controller.saving ? const CircularProgressIndicator() : const Text('Lưu')),
        ])),
      ])),
  );
}
