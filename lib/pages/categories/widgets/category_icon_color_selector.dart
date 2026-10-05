import 'package:flutter/material.dart';

import '../../../constants/constants.dart';
import '../../../ui/device.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/settings_tiles.dart';

class CategoryIconColorSelector extends StatefulWidget {
  final String selectedIcon;
  final int selectedColor;
  final Function(String) onIconChanged;
  final Function(int)? onColorChanged;

  const CategoryIconColorSelector({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconChanged,
    this.onColorChanged,
  });

  @override
  State<CategoryIconColorSelector> createState() =>
      _CategoryIconColorSelectorState();
}

class _CategoryIconColorSelectorState extends State<CategoryIconColorSelector> {
  final PageController _pageController = PageController();
  String selectedIconCategory = mapIconsList.keys.first;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'Look',
      children: [
        Padding(
          padding: const EdgeInsets.all(Sizes.md),
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final key in mapIconsList.keys)
                      CategoryTab(
                        category: key,
                        isSelected: selectedIconCategory == key,
                        onSelected: () {
                          setState(() => selectedIconCategory = key);
                          _pageController.animateToPage(
                            mapIconsList.keys.toList().indexOf(key),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Sizes.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 7;
                  final itemSize =
                      (constraints.maxWidth - (crossAxisCount - 1) * Sizes.sm) /
                      crossAxisCount;
                  var maxRows = 0;
                  for (final icons in mapIconsList.values) {
                    final rows = (icons.length / crossAxisCount).ceil();
                    if (rows > maxRows) maxRows = rows;
                  }
                  return SizedBox(
                    height: maxRows * itemSize + (maxRows - 1) * Sizes.sm,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) => setState(
                        () => selectedIconCategory = mapIconsList.keys
                            .elementAt(index),
                      ),
                      children: [
                        for (final icons in mapIconsList.values)
                          IconsGrid(
                            icons: icons,
                            selectedIcon: widget.selectedIcon,
                            selectedColor:
                                categoryColorListTheme[widget.selectedColor],
                            onIconChanged: widget.onIconChanged,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (widget.onColorChanged != null)
          ColorGrid(
            selectedColor: widget.selectedColor,
            onColorChanged: widget.onColorChanged!,
          ),
      ],
    );
  }
}

class CategoryTab extends StatelessWidget {
  const CategoryTab({
    required this.category,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  final String category;
  final bool isSelected;
  final Function() onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Sizes.xs),
      child: TogglePill(
        label: category,
        selected: isSelected,
        onTap: onSelected,
      ),
    );
  }
}

class IconsGrid extends StatelessWidget {
  const IconsGrid({
    required this.icons,
    required this.selectedIcon,
    required this.onIconChanged,
    this.selectedColor,
    super.key,
  });

  final Map<String, IconData> icons;
  final String selectedIcon;
  final Color? selectedColor;
  final Function(String) onIconChanged;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return GridView.builder(
      itemCount: icons.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: Sizes.sm,
        crossAxisSpacing: Sizes.sm,
      ),
      itemBuilder: (context, index) {
        final name = icons.keys.elementAt(index);
        final selected = iconList[selectedIcon] == icons[name];
        return GestureDetector(
          onTap: () => onIconChanged(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected
                  ? selectedColor ?? visual.accent
                  : visual.textPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icons[name],
              color: selected ? Colors.white : visual.textPrimary,
              size: 22,
            ),
          ),
        );
      },
    );
  }
}

class ColorGrid extends StatefulWidget {
  const ColorGrid({
    required this.selectedColor,
    required this.onColorChanged,
    super.key,
  });

  final int selectedColor;
  final Function(int) onColorChanged;

  @override
  State<ColorGrid> createState() => _ColorGridState();
}

class _ColorGridState extends State<ColorGrid> {
  bool showAllColors = false;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sizes.md, Sizes.md, Sizes.md, 0),
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: Sizes.sm,
                crossAxisSpacing: Sizes.sm,
              ),
              itemCount: showAllColors ? categoryColorListTheme.length : 16,
              itemBuilder: (context, index) {
                final isSelected = widget.selectedColor == index;
                return GestureDetector(
                  onTap: () => widget.onColorChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: categoryColorListTheme[index],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? visual.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => showAllColors = !showAllColors),
            icon: Icon(
              showAllColors
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 20,
            ),
            label: Text(showAllColors ? 'Fewer colors' : 'More colors'),
            style: TextButton.styleFrom(
              foregroundColor: visual.textSecondary,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
