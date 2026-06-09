import 'package:flutter/material.dart';

import 'product_form_field_styles.dart';

/// حقل تصنيف مع قائمة اقتراحات منسدلة (Autocomplete).
class ProductCategoryField extends StatelessWidget {
  const ProductCategoryField({
    super.key,
    required this.controller,
    required this.categoryOptions,
    required this.validator,
    this.isLoading = false,
  });

  final TextEditingController controller;
  final List<String> categoryOptions;
  final FormFieldValidator<String> validator;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return InputDecorator(
        decoration: ProductFormFieldStyles.decoration(labelText: 'التصنيف'),
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return categoryOptions;
        }
        return categoryOptions.where(
          (category) => category.toLowerCase().contains(query),
        );
      },
      displayStringForOption: (option) => option,
      onSelected: (selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.done,
          onChanged: (value) => controller.text = value,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          style: const TextStyle(color: ProductFormFieldStyles.textColor),
          decoration: ProductFormFieldStyles.decoration(
            labelText: 'التصنيف',
            hintText: categoryOptions.isEmpty
                ? 'اكتب اسم التصنيف (مثل: برجر)'
                : 'اختر من القائمة أو اكتب تصنيفاً جديداً',
            suffixIcon: Icon(
              Icons.arrow_drop_down_rounded,
              color: ProductFormFieldStyles.textColor,
            ),
          ),
          validator: validator,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final category = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      category,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                    onTap: () => onSelected(category),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
