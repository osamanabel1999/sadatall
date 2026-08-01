import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/orders/presentation/providers/orders_provider.dart';
import 'features/orders/presentation/screens/available_orders_screen.dart';
import 'features/orders/presentation/screens/current_order_screen.dart';
import 'features/orders/presentation/screens/delivered_orders_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/requests/presentation/screens/create_request_screen.dart';
import 'features/requests/presentation/screens/requests_list_screen.dart';
import 'features/announcements/presentation/screens/offers_screen.dart';
import 'features/chat/captain_support_chat_screen.dart';

final switchToCurrentOrderTab = StateProvider<VoidCallback?>((ref) => null);
final switchToAvailableOrdersTab = StateProvider<VoidCallback?>((ref) => null);

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(switchToCurrentOrderTab.notifier).state = () {
        if (mounted) setState(() => _currentIndex = 0);
      };
      ref.read(switchToAvailableOrdersTab.notifier).state = () {
        if (mounted) setState(() => _currentIndex = 1);
      };
    });
  }

  final List<Widget> _screens = [
    const CurrentOrderScreen(),
    const AvailableOrdersScreen(),
    const DeliveredOrdersScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'الطلب الحالي',
    'الطلبات المتاحة',
    'الطلبات المكتملة',
    'الملف الشخصي',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_currentIndex == 1) // Available orders tab
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref
                    .read(availableOrdersProvider.notifier)
                    .loadOrders(refresh: true);
              },
            ),
          if (_currentIndex == 2) // Delivered orders tab
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref
                    .read(deliveredOrdersProvider.notifier)
                    .loadOrders(refresh: true);
              },
            ),
          // IconButton(
          //   icon: const Icon(Icons.notifications),
          //   onPressed: () {
          //     // TODO: Show notifications
          //   },
          // ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        // Reset pagination when switching to orders tabs
        if (index == 1) {
          // Available orders
          ref.read(availableOrdersProvider.notifier).resetPagination();
        } else if (index == 2) {
          // Delivered orders
          ref.read(deliveredOrdersProvider.notifier).resetPagination();
        }

        setState(() {
          _currentIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.onSurfaceVariant,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'الطلب الحالي',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: 'طلبات متاحة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.check_circle),
          label: 'مكتملة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'الملف الشخصي',
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    final captain = ref.watch(authStateProvider).captain;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.surface,
                  backgroundImage: captain?.photoUrl != null
                      ? NetworkImage(captain!.photoUrl!)
                      : null,
                  child: captain?.photoUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  captain?.userName ?? 'اسم الكابتن',
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (captain?.email != null)
                  Text(
                    captain!.email,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle),
            title: const Text('إنشاء طلب'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateRequestScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('طلباتي السابقة'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RequestsListScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('عروض وأخبار'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CaptainOffersScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('الدعم'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CaptainSupportChatScreen(),
                ),
              );
            },
          ),
          const Divider(),
          // ListTile(
          //   leading: const Icon(Icons.settings),
          //   title: const Text('الإعدادات'),
          //   onTap: () {
          //     Navigator.of(context).pop();
          //     // TODO: Navigate to settings
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.help),
          //   title: const Text('المساعدة'),
          //   onTap: () {
          //     Navigator.of(context).pop();
          //     // TODO: Navigate to help
          //   },
          // ),
          // const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            onTap: () {
              Navigator.of(context).pop();
              _showLogoutDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من التطبيق؟'),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('تسجيل الخروج'),
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(authStateProvider.notifier).logout();
              },
            ),
          ],
        );
      },
    );
  }
}
