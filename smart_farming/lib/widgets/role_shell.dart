import 'package:flutter/material.dart';

class ShellTab {
  const ShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.refreshOnOpen = true,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function(BuildContext context, ValueChanged<int> goToTab)
  builder;
  final bool refreshOnOpen;
}

class RoleShell extends StatefulWidget {
  RoleShell({super.key, required this.tabs})
    : assert(tabs.length >= 2 && tabs.length <= 5);

  final List<ShellTab> tabs;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;
  late final List<bool> _visited = List.generate(
    widget.tabs.length,
    (i) => i == 0,
  );
  late final List<int> _versions = List.filled(widget.tabs.length, 0);

  void _select(int index) {
    if (index == _index) return;

    setState(() {
      _visited[index] = true;
      if (widget.tabs[index].refreshOnOpen) {
        _versions[index]++;
      }
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _visited[i]
                ? KeyedSubtree(
                    key: ValueKey('tab-$i-${_versions[i]}'),
                    child: widget.tabs[i].builder(context, _select),
                  )
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
