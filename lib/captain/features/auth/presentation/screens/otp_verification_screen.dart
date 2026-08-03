import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import 'reset_password_screen.dart';

class CaptainOtpVerificationScreen extends StatefulWidget {
  final String email;

  const CaptainOtpVerificationScreen({super.key, required this.email});

  @override
  State<CaptainOtpVerificationScreen> createState() =>
      _CaptainOtpVerificationScreenState();
}

class _CaptainOtpVerificationScreenState
    extends State<CaptainOtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _secondsLeft = 600;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 600);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل الرمز المكون من 6 أرقام'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/verify-otp');
      final response = await http.post(
        uri,
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': widget.email,
          'role': 'captain',
          'otp': _otp,
        }),
      );
      if (!mounted) return;
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final resetToken = body['data']['resetToken'] as String;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CaptainResetPasswordScreen(resetToken: resetToken),
          ),
        );
      } else {
        final msg = body['error'] ?? 'الرمز غير صحيح أو منتهي الصلاحية';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الاتصال بالخادم'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password');
      final response = await http.post(
        uri,
        headers: ApiConfig.headers,
        body: jsonEncode({'email': widget.email, 'role': 'captain'}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز جديد'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String message = 'حدث خطأ، يرجى المحاولة مرة أخرى';
        try {
          final body = jsonDecode(response.body);
          message = body['error'] ?? body['message'] ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الاتصال بالخادم: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        title: const Text(
          'التحقق من الرمز',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: AppColors.primary),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.mark_email_read_outlined,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'تم إرسال الرمز',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'أدخل الرمز المرسل إلى\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 40),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace &&
                              _controllers[i].text.isEmpty &&
                              i > 0) {
                            _focusNodes[i - 1].requestFocus();
                            _controllers[i - 1].clear();
                          }
                        },
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.white30,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.white30,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.secondaryLight,
                          ),
                          onChanged: (v) {
                            if (v.length > 1) {
                              // Handle pasted multi-digit input
                              final digits = v
                                  .replaceAll(RegExp(r'[^0-9]'), '')
                                  .split('');
                              for (
                                var j = 0;
                                j < digits.length && i + j < 6;
                                j++
                              ) {
                                _controllers[i + j].text = digits[j];
                              }
                              final next = (i + digits.length).clamp(0, 5);
                              _focusNodes[next].requestFocus();
                              return;
                            }
                            if (v.isNotEmpty && i < 5) {
                              _focusNodes[i + 1].requestFocus();
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _secondsLeft > 0
                    ? 'صالح لمدة: $_timerText'
                    : 'انتهت صلاحية الرمز',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _secondsLeft > 0 ? Colors.white70 : Colors.redAccent,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'تحقق',
                onPressed: _verifyOtp,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: (_secondsLeft == 0 && !_isResending)
                    ? _resendOtp
                    : null,
                child: _isResending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'إعادة إرسال الرمز',
                        style: TextStyle(
                          color: _secondsLeft == 0
                              ? AppColors.primary
                              : Colors.white30,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
