import 'package:flutter/material.dart';
import 'step_1_details.dart';
import 'step_2_features.dart';
import 'step_3_facilities.dart';
import 'step_4_price_description.dart';
import 'step_5_upload_images.dart';
import 'apartment_form_data.dart';

class AddApartmentPage extends StatefulWidget {
  final String hostUID;

  const AddApartmentPage({super.key, required this.hostUID});

  @override
  State<AddApartmentPage> createState() => _AddApartmentPageState();
}

class _AddApartmentPageState extends State<AddApartmentPage> {
  final PageController _pageController = PageController();
  final ApartmentFormData formData = ApartmentFormData();
  int _currentStep = 0;

  void _next(ApartmentFormData? data) {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Apartment"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentStep + 1) / 5),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
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
      ),
    );
  }
}