import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'vendors/vendors_list_screen.dart';
import 'orders/orders_list_screen.dart';
import 'settings/settings_screen.dart';
import 'offers/offers_screen.dart';
import 'chat/support_chat_tab.dart';
import '../main.dart' show openOffersTab;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    openOffersTab.addListener(_onOpenOffers);
  }

  @override
  void dispose() {
    openOffersTab.removeListener(_onOpenOffers);
    super.dispose();
  }

  void _onOpenOffers() {
    if (mounted) setState(() => _currentIndex = 4);
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const VendorsListScreen(),
    const OrdersListScreen(),
    const SettingsScreen(),
    const OffersScreen(),
    const SupportChatTab(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'الرئيسية',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'المتاجر',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.shopping_bag_outlined),
      activeIcon: Icon(Icons.shopping_bag),
      label: 'طلباتي',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'الإعدادات',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.local_offer_outlined),
      activeIcon: Icon(Icons.local_offer),
      label: 'عروض',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.support_agent_outlined),
      activeIcon: Icon(Icons.support_agent),
      label: 'الدعم',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          if ((index == 2 || index == 3 || index == 5) && !authProvider.isAuthenticated) {
            Navigator.of(context).pushNamed('/login');
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: _navItems,
        elevation: 8,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
