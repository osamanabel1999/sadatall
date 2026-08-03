import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/neighborhood_dropdown.dart';
import '../../widgets/common/category_selector.dart';
import '../../widgets/common/image_picker_widget.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _authService = AuthService();
  final _locationService = LocationService();

  bool _isLoading = false;
  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _selectedNeighborhoodId;
  List<String> _selectedCategoryIds = [];
  File? _selectedImage;
  String? _imageError;

  @override
  void dispose() {
    _vendorNameController.dispose();
    _contactNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final result = await _locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        if (result.success) {
          setState(() {
            _latitude = result.latitude;
            _longitude = result.longitude;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم الحصول على الموقع بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'فشل في الحصول على الموقع'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      setState(() {
        _imageError = 'يرجى إضافة صورة للمتجر';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة صورة للمتجر'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى الحصول على الموقع أولاً'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedNeighborhoodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الحي'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تصنيف واحد على الأقل'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signup(
        vendorName: _vendorNameController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        password: _passwordController.text,
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        neighborhoodId: int.parse(_selectedNeighborhoodId!),
        categories: _selectedCategoryIds.map((id) => int.parse(id)).toList(),
        image: _selectedImage!,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الحساب بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          // Navigate to dashboard
          Navigator.of(context).pushReplacementNamed('/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'فشل إنشاء الحساب'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateToLogin,
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'جاري إنشاء الحساب...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'أنشئ حساب تاجر جديد',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'املأ البيانات التالية لإنشاء حساب جديد',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Store Image
                ImagePickerWidget(
                  initialImage: _selectedImage,
                  label: 'صورة المتجر',
                  hint: 'اضغط لإضافة صورة المتجر',
                  required: true,
                  height: 150,
                  onImageSelected: (file) {
                    setState(() {
                      _selectedImage = file;
                      _imageError = null;
                    });
                  },
                ),
                if (_imageError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _imageError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Vendor Name
                CustomTextField(
                  label: 'اسم المتجر',
                  hint: 'أدخل اسم المتجر',
                  controller: _vendorNameController,
                  prefixIcon: Icons.store,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال اسم المتجر';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Contact Number
                CustomTextField(
                  label: 'رقم التواصل',
                  hint: 'أدخل رقم التواصل',
                  controller: _contactNumberController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم التواصل';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  label: 'كلمة المرور',
                  hint: 'أدخل كلمة المرور',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                CustomTextField(
                  label: 'تأكيد كلمة المرور',
                  hint: 'أعد إدخال كلمة المرور',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى تأكيد كلمة المرور';
                    }
                    if (value != _passwordController.text) {
                      return 'كلمة المرور غير متطابقة';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Address
                CustomTextField(
                  label: 'العنوان',
                  hint: 'أدخل عنوان المتجر',
                  controller: _addressController,
                  prefixIcon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال العنوان';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Description
                CustomTextField(
                  label: 'وصف المتجر',
                  hint: 'أدخل وصف مختصر للمتجر',
                  controller: _descriptionController,
                  prefixIcon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال الوصف';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Neighborhood Selection
                NeighborhoodDropdown(
                  selectedNeighborhoodId: _selectedNeighborhoodId,
                  onChanged: (value) {
                    setState(() {
                      _selectedNeighborhoodId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى اختيار الحي';
                    }
                    return null;
                  },
                  labelText: 'الحي',
                  prefixIcon:
                      Icon(Icons.location_city, color: Colors.purple[700]),
                ),
                const SizedBox(height: 16),

                // Category Selection
                CategorySelector(
                  selectedCategoryIds: _selectedCategoryIds,
                  onChanged: (categoryIds) {
                    setState(() {
                      _selectedCategoryIds = categoryIds;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى اختيار تصنيف واحد على الأقل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الموقع',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_latitude != null && _longitude != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.successColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تم الحصول على الموقع بنجاح\nخط العرض: ${_latitude!.toStringAsFixed(6)}\nخط الطول: ${_longitude!.toStringAsFixed(6)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: AppTheme.warningColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'لم يتم تحديد الموقع بعد',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'الحصول على الموقع الحالي',
                        onPressed: _getCurrentLocation,
                        isLoading: _isLoadingLocation,
                        type: ButtonType.outline,
                        icon: Icons.my_location,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Signup Button
                CustomButton(
                  text: 'إنشاء الحساب',
                  onPressed: _signup,
                  isLoading: _isLoading,
                  height: 52,
                ),
                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'هل لديك حساب؟ ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _navigateToLogin,
                      child: Text(
                        'تسجيل الدخول',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: mediaQuery.padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
