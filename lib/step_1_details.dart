import 'package:flutter/material.dart';
import 'apartment_form_data.dart';

class Step1Details extends StatefulWidget {
  final Function(ApartmentFormData) onNext;
  final ApartmentFormData formData;

  const Step1Details({
    super.key,
    required this.onNext,
    required this.formData,
  });

  @override
  State<Step1Details> createState() => _Step1DetailsState();
}

class _Step1DetailsState extends State<Step1Details> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.formData.title);
    _addressController = TextEditingController(text: widget.formData.address);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      widget.formData.title = _titleController.text.trim();
      widget.formData.address = _addressController.text.trim();
      widget.onNext(widget.formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 6,
              margin: EdgeInsets.all(isMobile ? 12 : 16),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.lightBlue.withOpacity(0.3),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                width: constraints.maxWidth > 600 ? 500 : double.infinity,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Apartment Type and Address',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          fontSize: isMobile ? 20 : 24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 20 : 24),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Apartment Title',
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.lightBlue.shade700, width: 2),
                          ),
                          prefixIcon: const Icon(Icons.title, color: Colors.black),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 12 : 16,
                          ),
                        ),
                        style: const TextStyle(color: Colors.black),
                        validator: (val) => val == null || val.isEmpty
                            ? 'Please enter a title'
                            : null,
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.lightBlue.shade700, width: 2),
                          ),
                          prefixIcon: const Icon(Icons.location_on, color: Colors.black),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 12 : 16,
                          ),
                        ),
                        style: const TextStyle(color: Colors.black),
                        validator: (val) => val == null || val.isEmpty
                            ? 'Please enter address'
                            : null,
                      ),
                      SizedBox(height: isMobile ? 20 : 30),
                      FilledButton.icon(
                        onPressed: _nextStep,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(double.infinity, isMobile ? 44 : 48),
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          textStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 15 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}