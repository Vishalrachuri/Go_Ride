import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final IconData? icon;
  final double? width;
  final bool fullWidth;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.icon,
    this.width,
    this.fullWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isOutlined
        ? OutlinedButton.styleFrom(
      side: BorderSide(color: Theme.of(context).primaryColor),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      minimumSize: Size(fullWidth ? double.infinity : (width ?? 120), 48),
    )
        : ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      minimumSize: Size(fullWidth ? double.infinity : (width ?? 120), 48),
    );

    Widget buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null && !isLoading) ...[
          Icon(icon),
          const SizedBox(width: 8),
        ],
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );

    return isOutlined
        ? OutlinedButton(
      style: buttonStyle,
      onPressed: isLoading ? null : onPressed,
      child: buttonChild,
    )
        : ElevatedButton(
      style: buttonStyle,
      onPressed: isLoading ? null : onPressed,
      child: buttonChild,
    );
  }
}