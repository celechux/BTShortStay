import 'package:flutter/material.dart';
import 'apartment_form_data.dart';

class Step2Features extends StatefulWidget {
  final Function(ApartmentFormData) onNext;
  final VoidCallback onBack;
  final ApartmentFormData formData;

  const Step2Features({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.formData,
  });

  @override
  State<Step2Features> createState() => _Step2FeaturesState();
}

class _Step2FeaturesState extends State<Step2Features> {
  late int bedrooms;
  late int beds;
  late int bathrooms;
  late int kitchens;

  @override
  void initState() {
    super.initState();
    bedrooms = widget.formData.bedrooms;
    beds = widget.formData.beds;
    bathrooms = widget.formData.bathrooms;
    kitchens = widget.formData.kitchens;
  }

  void _saveAndNext() {
    widget.formData.bedrooms = bedrooms;
    widget.formData.beds = beds;
    widget.formData.bathrooms = bathrooms;
    widget.formData.kitchens = kitchens;
    widget.onNext(widget.formData);
  }

  Widget buildCounter(String label, int value, VoidCallback onAdd, VoidCallback onRemove, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 4 : 6),
                  child: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.black,
                    size: isMobile ? 20 : 24,
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(minWidth: isMobile ? 30 : 36),
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 4 : 6),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: Colors.black,
                    size: isMobile ? 20 : 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                width: constraints.maxWidth > 600 ? 500 : double.infinity,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Apartment Features',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black,
                        fontSize: isMobile ? 20 : 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isMobile ? 20 : 30),
                    
                    // Features Grid
                    isMobile
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: buildCounter(
                                      'Bedrooms',
                                      bedrooms,
                                      () => setState(() => bedrooms++),
                                      () {
                                        if (bedrooms > 0) setState(() => bedrooms--);
                                      },
                                      isMobile,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: buildCounter(
                                      'Beds',
                                      beds,
                                      () => setState(() => beds++),
                                      () {
                                        if (beds > 0) setState(() => beds--);
                                      },
                                      isMobile,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildCounter(
                                      'Bathrooms',
                                      bathrooms,
                                      () => setState(() => bathrooms++),
                                      () {
                                        if (bathrooms > 0) setState(() => bathrooms--);
                                      },
                                      isMobile,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: buildCounter(
                                      'Kitchens',
                                      kitchens,
                                      () => setState(() => kitchens++),
                                      () {
                                        if (kitchens > 0) setState(() => kitchens--);
                                      },
                                      isMobile,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 16,
                            runSpacing: 20,
                            alignment: WrapAlignment.center,
                            children: [
                              buildCounter(
                                'Bedrooms',
                                bedrooms,
                                () => setState(() => bedrooms++),
                                () {
                                  if (bedrooms > 0) setState(() => bedrooms--);
                                },
                                isMobile,
                              ),
                              buildCounter(
                                'Beds',
                                beds,
                                () => setState(() => beds++),
                                () {
                                  if (beds > 0) setState(() => beds--);
                                },
                                isMobile,
                              ),
                              buildCounter(
                                'Bathrooms',
                                bathrooms,
                                () => setState(() => bathrooms++),
                                () {
                                  if (bathrooms > 0) setState(() => bathrooms--);
                                },
                                isMobile,
                              ),
                              buildCounter(
                                'Kitchens',
                                kitchens,
                                () => setState(() => kitchens++),
                                () {
                                  if (kitchens > 0) setState(() => kitchens--);
                                },
                                isMobile,
                              ),
                            ],
                          ),
                    
                    SizedBox(height: isMobile ? 20 : 30),
                    
                    // Navigation Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onBack,
                            icon: Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                              size: isMobile ? 18 : 20,
                            ),
                            label: Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(0, isMobile ? 44 : 48),
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveAndNext,
                            icon: Icon(
                              Icons.arrow_forward,
                              size: isMobile ? 18 : 20,
                            ),
                            label: Text(
                              'Next',
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: Size(0, isMobile ? 44 : 48),
                              backgroundColor: Colors.lightBlue,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                              ),
                            ),
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