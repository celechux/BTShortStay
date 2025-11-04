import 'package:flutter/material.dart';
import 'apartment_form_data.dart';

class Step3Facilities extends StatefulWidget {
  final Function(ApartmentFormData) onNext;
  final VoidCallback onBack;
  final ApartmentFormData formData;

  const Step3Facilities({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.formData,
  });

  @override
  State<Step3Facilities> createState() => _Step3FacilitiesState();
}

class _Step3FacilitiesState extends State<Step3Facilities> {
  final List<String> _facilities = [
    'WiFi',
    'TV',
    'Constant Electricity',
    'AC',
    'Gaming Console',
    'Workspace',
    'Swimming Pool',
    'Parking Space',
  ];

  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.formData.facilities);
  }

  void _toggleFacility(String name) {
    setState(() {
      _selected.contains(name) ? _selected.remove(name) : _selected.add(name);
    });
  }

  void _saveAndNext() {
    widget.formData.facilities = _selected;
    widget.onNext(widget.formData);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 6,
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.lightBlue.withOpacity(0.3),
              child: Container(
                width: constraints.maxWidth > 600 ? 500 : double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Facilities',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _facilities.map((facility) {
                        final selected = _selected.contains(facility);
                        return ChoiceChip(
                          label: Text(
                            facility,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: selected,
                          selectedColor: Colors.black,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.black, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (_) => _toggleFacility(facility),
                          elevation: 0,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          label: const Text('Back', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black, width: 1.5),
                            foregroundColor: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saveAndNext,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(120, 48),
                            backgroundColor: Colors.lightBlue,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}