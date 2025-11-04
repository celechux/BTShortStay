import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apartment_form_data.dart';

class Step4PriceDesc extends StatefulWidget {
  final Function(ApartmentFormData) onNext;
  final VoidCallback onBack;
  final ApartmentFormData formData;

  const Step4PriceDesc({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.formData,
  });

  @override
  State<Step4PriceDesc> createState() => _Step4PriceDescState();
}

class _Step4PriceDescState extends State<Step4PriceDesc> {
  late int maxGuests;
  late TextEditingController _priceController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    maxGuests = widget.formData.maxGuests;
    _priceController = TextEditingController(text: widget.formData.price);
    _descController = TextEditingController(text: widget.formData.description);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a price')),
      );
      return;
    }

    widget.formData.maxGuests = maxGuests;
    widget.formData.price = _priceController.text.trim();
    widget.formData.description = _descController.text.trim();
    widget.onNext(widget.formData);
  }

  Widget buildCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Maximum Guests', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (maxGuests > 1) setState(() => maxGuests--);
                },
                icon: const Icon(Icons.remove_circle_outline, color: Colors.black),
              ),
              Text('$maxGuests', style: const TextStyle(fontSize: 16, color: Colors.black)),
              IconButton(
                onPressed: () => setState(() => maxGuests++),
                icon: const Icon(Icons.add_circle_outline, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Center(
            child: Card(
              elevation: 6,
              margin: const EdgeInsets.all(16),
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
                  children: [
                    Text(
                      'Pricing & Description',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black),
                    ),
                    const SizedBox(height: 24),

                    buildCounter(),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Price per Night (₦)',
                        prefixText: '₦ ',
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.black),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.black),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade700, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.money, color: Colors.black),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 20),

                    Tooltip(
                      message: 'Give more details on this apartment if necessary',
                      child: TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.lightBlue.shade700, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignLabelWithHint: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.arrow_back, color: Colors.black),
                            label: const Text('Back', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(100, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _nextStep,
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
                        ),
                      ],
                    )
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