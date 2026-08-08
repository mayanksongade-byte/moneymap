import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../home/data/models/category_model.dart';
import '../providers/category_provider.dart';

const List<String> _emojiChoices = [
  '🍔', '🚗', '🛒', '🏠', '💊', '🎮', '📚', '💡', '💰', '📈',
  '📊', '🎁', '✈️', '🐾', '🎬', '👕', '☕', '⚽', '🎵', '📌',
  '💳', '🏦', '📱', '⚡', '🧾', '🏥', '🚕', '⛽', '🧳', '👶',
  '🎉', '🛠️', '💼', '🏋️', '🎯', '🎂', '🧑‍🍳', '🚌', '🏨', '🩺',
];

const List<String> _colorChoices = [
  '#EF4444', '#F59E0B', '#10B981', '#3B82F6',
  '#8B5CF6', '#EC4899', '#6B7280', '#14B8A6',
  '#F97316', '#EAB308', '#22C55E', '#06B6D4',
  '#6366F1', '#D946EF', '#84CC16', '#F43F5E',
];

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.primary;
  }
}

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // animation listener = smooth pill/FAB follow while swiping
    _tabController.animation?.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _tabPos => _tabController.animation?.value ?? 0;
  int get _activeIndex => _tabPos.round();

  // ---------------- actions ----------------

  Future<void> _openActions(BuildContext context, CategoryModel category) async {
    HapticFeedback.selectionClick();
    final colors = context.colors;
    final c = _hexColor(category.color);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 26,
              backgroundColor: c.withValues(alpha: .15),
              child: Text(category.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 10),
            Text(category.name,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            Text(
              category.type == 'income' ? 'Income category' : 'Expense category',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Delete category',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, category);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, CategoryModel category) async {
    final provider = context.read<CategoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete category?'),
        content: Text(
            'Remove "${category.name}" permanently? Past transactions stay intact.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    final success = await provider.deleteCategory(category.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? null : AppColors.error,
        content: Text(success
            ? '"${category.name}" deleted'
            : (provider.error ?? 'Failed to delete')),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context, String defaultType) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCategorySheet(defaultType: defaultType),
    );
  }

  // ---------------- grid ----------------

  Widget _buildGrid(BuildContext context, String type) {
    final colors = context.colors;
    final provider = context.watch<CategoryProvider>();
    final all = provider.byType(type);
    final categories = _query.isEmpty
        ? all
        : all
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    if (provider.isLoading && all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty) {
      return _EmptyState(
        icon: _query.isEmpty
            ? Icons.category_outlined
            : Icons.search_off_rounded,
        title: _query.isEmpty ? 'No categories yet' : 'Nothing matches',
        subtitle: _query.isEmpty
            ? 'Tap the button below to create your first one'
            : 'Try a different search term',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .95,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _StaggerIn(
          index: index,
          key: ValueKey(category.id),
          child: _CategoryTile(
            category: category,
            isCustom: provider.isCustom(category.id),
            onLongPress: provider.isCustom(category.id)
                ? () => _openActions(context, category)
                : null,
          ),
        );
      },
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<CategoryProvider>();
    final expenseCount = provider.byType('expense').length;
    final incomeCount = provider.byType('income').length;
    final accent = Color.lerp(
        AppColors.error, AppColors.success, _tabPos.clamp(0, 1))!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- header ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Categories',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary)),
                        Text(
                          '${expenseCount + incomeCount} total \u00b7 organize your spending',
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: _searchOpen
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) {
                          _searchCtrl.clear();
                          _query = '';
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // ---------- search ----------
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _searchOpen
                  ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: colors.textPrimary),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search categories',
                    hintStyle: TextStyle(color: colors.textHint),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              )
                  : const SizedBox(width: double.infinity),
            ),

            const SizedBox(height: 14),

            // ---------- sliding segmented control ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth / 2;
                    return Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 1),
                          alignment: Alignment(
                              (_tabPos.clamp(0, 1) * 2) - 1, 0),
                          child: Container(
                            width: w,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: .22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _pillTab('Expense', 0, expenseCount,
                                AppColors.error),
                            _pillTab('Income', 1, incomeCount,
                                AppColors.success),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildGrid(context, 'expense'),
                  _buildGrid(context, 'income'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
      _buildFab(context, _activeIndex == 0 ? 'expense' : 'income'),
    );
  }

  Widget _pillTab(String label, int index, int count, Color activeColor) {
    final colors = context.colors;
    final t = (1 - (_tabPos - index).abs()).clamp(0.0, 1.0);
    final color = Color.lerp(colors.textSecondary, activeColor, t)!;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _tabController.animateTo(index);
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: color)),
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Color.lerp(colors.surface,
                      activeColor.withValues(alpha: .15), t),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context, String type) {
    final isIncome = type == 'income';
    final base = isIncome ? AppColors.success : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [base, Color.lerp(base, Colors.black, .18)!],
          ),
          boxShadow: [
            BoxShadow(
                color: base.withValues(alpha: .42),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withValues(alpha: .18),
            onTap: () => _showAddCategorySheet(context, type),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      'Add ${isIncome ? 'Income' : 'Expense'} Category',
                      key: ValueKey(isIncome),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- small widgets ----------------

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: colors.border),
          ),
          child: Icon(icon, size: 17, color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final CategoryModel category;
  final bool isCustom;
  final VoidCallback? onLongPress;
  const _CategoryTile({
    required this.category,
    required this.isCustom,
    this.onLongPress,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = _hexColor(widget.category.color);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? .94 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: .14),
                        shape: BoxShape.circle,
                        border:
                        Border.all(color: c.withValues(alpha: .30)),
                      ),
                      child: Center(
                        child: Text(widget.category.icon,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        widget.category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isCustom)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerIn({required this.index, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index % 9) * 45),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colors.textDisabled),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                TextStyle(color: colors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------------- add sheet ----------------

class _AddCategorySheet extends StatefulWidget {
  final String defaultType;
  const _AddCategorySheet({required this.defaultType});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emojiSearch = TextEditingController();
  late String _type;
  String _selectedEmoji = _emojiChoices.first;
  String _selectedColor = _colorChoices.first;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiSearch.dispose();
    super.dispose();
  }

  bool get _valid => _nameController.text.trim().length >= 2;

  Future<void> _save() async {
    if (!_valid) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final provider = context.read<CategoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.addCategory(CategoryModel(
      id: '',
      name: _nameController.text.trim(),
      icon: _selectedEmoji,
      type: _type,
      color: _selectedColor,
    ));

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Navigator.pop(context);
    } else {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(provider.error ?? 'Failed to add category'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final previewColor = _hexColor(_selectedColor);
    final name = _nameController.text.trim();
    final previewName = name.isEmpty ? 'New Category' : name;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('New Category',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Pick an icon, colour and name',
                        style: TextStyle(
                            fontSize: 12.5, color: colors.textSecondary)),
                    const SizedBox(height: 16),

                    // live preview
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          previewColor.withValues(alpha: .14),
                          previewColor.withValues(alpha: .04),
                        ]),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: previewColor.withValues(alpha: .30)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: previewColor.withValues(alpha: .18),
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text(_selectedEmoji,
                                    style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(previewName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: previewColor,
                                borderRadius: BorderRadius.circular(9)),
                            child: Text(
                              _type == 'income' ? 'Income' : 'Expense',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    _SegToggle(
                      type: _type,
                      onChanged: (t) {
                        HapticFeedback.selectionClick();
                        setState(() => _type = t);
                      },
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 20,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Category name',
                        counterText: '',
                        suffixText: '${name.length}/20',
                        suffixStyle: TextStyle(
                            fontSize: 11, color: colors.textDisabled),
                        hintStyle: TextStyle(color: colors.textHint),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _Label('Icon', trailing: _selectedEmoji),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 108,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _emojiChoices.length,
                        itemBuilder: (_, i) {
                          final emoji = _emojiChoices[i];
                          final selected = emoji == _selectedEmoji;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedEmoji = emoji);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? previewColor.withValues(alpha: .16)
                                    : colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: selected
                                      ? previewColor
                                      : Colors.transparent,
                                  width: 1.6,
                                ),
                              ),
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    const _Label('Color'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colorChoices.map((hex) {
                        final selected = hex == _selectedColor;
                        final color = _hexColor(hex);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = hex);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: selected ? 38 : 34,
                            height: selected ? 38 : 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: selected
                                  ? [
                                BoxShadow(
                                    color:
                                    color.withValues(alpha: .55),
                                    blurRadius: 12)
                              ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // sticky save button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 20 + MediaQuery.of(context).padding.bottom * .2),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _valid ? 1 : .5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [
                        previewColor,
                        Color.lerp(previewColor, Colors.black, .2)!,
                      ]),
                    ),
                    child: ElevatedButton(
                      onPressed: (_isSaving || !_valid) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Add Category',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? trailing;
  const _Label(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary)),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(trailing!, style: const TextStyle(fontSize: 14)),
        ],
      ],
    );
  }
}

class _SegToggle extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  const _SegToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget item(String value, String label, Color c) {
      final active = type == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? c.withValues(alpha: .12)
                  : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? c : Colors.transparent, width: 1.4),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? c : colors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Row(children: [
      item('expense', 'Expense', AppColors.error),
      const SizedBox(width: 10),
      item('income', 'Income', AppColors.success),
    ]);
  }
}
