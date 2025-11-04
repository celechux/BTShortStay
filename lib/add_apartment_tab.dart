import 'package:flutter/material.dart';
import 'step_1_details.dart';
import 'step_2_features.dart';
import 'step_3_facilities.dart';
import 'step_4_price_description.dart';
import 'step_5_upload_images.dart';
import 'apartment_form_data.dart';

class AddApartmentTab extends StatefulWidget {
  final String hostUID;

  const AddApartmentTab({super.key, required this.hostUID});

  @override
  State<AddApartmentTab> createState() => _AddApartmentTabState();
}

class _AddApartmentTabState extends State<AddApartmentTab> {
  final PageController _pageController = PageController();
  final ApartmentFormData formData = ApartmentFormData();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    print('AddApartmentTab initialized');
  }

  void _next(ApartmentFormData data) {
    print('Next called from step $_currentStep');
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    print('Back called from step $_currentStep');
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building AddApartmentTab - Current Step: $_currentStep');
    
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        // Progress indicator
        Container(
          height: 4,
          color: Colors.white,
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 5,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        // Step indicator text
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          width: double.infinity,
          child: Text(
            'Step ${_currentStep + 1} of 5',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        // PageView with fixed height
        SizedBox(
          height: MediaQuery.of(context).size.height - 250,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              print('Page changed to: $index');
            },
            children: [
              Step1Details(
                formData: formData,
                onNext: _next,
              ),
              Step2Features(
                formData: formData,
                onNext: _next,
                onBack: _back,
              ),
              Step3Facilities(
                formData: formData,
                onNext: _next,
                onBack: _back,
              ),
              Step4PriceDesc(
                formData: formData,
                onNext: _next,
                onBack: _back,
              ),
              Step5UploadImages(
                formData: formData,
                onBack: _back,
                hostUID: widget.hostUID,
              ),
            ],
          ),
        ),
      ],
    )
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}