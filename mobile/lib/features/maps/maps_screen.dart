import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/map_toolbar.dart';
import 'widgets/map_sidebar.dart';
import 'widgets/map_bottom_bar.dart';
import 'widgets/map_glide_banner.dart';
import 'widgets/layer_picker.dart';
import 'widgets/map_settings_panel.dart';
import 'widgets/map_view.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  bool _showLayerPicker = false;
  bool _showSettings = false;
  String _selectedBaseLayer = 'satellite';

  void _toggleLayerPicker() {
    setState(() {
      _showLayerPicker = !_showLayerPicker;
      if (_showLayerPicker) _showSettings = false;
    });
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      if (_showSettings) _showLayerPicker = false;
    });
  }

  void _onBaseLayerChanged(String layer) {
    setState(() => _selectedBaseLayer = layer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map fills the entire screen
          const Positioned.fill(
            child: EfbMapView(),
          ),

          // Top toolbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MapToolbar(
              onLayersTap: _toggleLayerPicker,
              onSettingsTap: _toggleSettings,
            ),
          ),

          // Left sidebar controls
          const Positioned(
            left: 0,
            top: 160,
            child: MapSidebar(),
          ),

          // Glide range banner
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: MapGlideBanner(),
          ),

          // Bottom info bar
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MapBottomBar(),
          ),

          // Layer picker overlay
          if (_showLayerPicker)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _toggleLayerPicker,
                child: Container(
                  color: Colors.black38,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: LayerPicker(
                      selectedBaseLayer: _selectedBaseLayer,
                      onBaseLayerChanged: _onBaseLayerChanged,
                      onClose: _toggleLayerPicker,
                    ),
                  ),
                ),
              ),
            ),

          // Settings panel overlay
          if (_showSettings)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _toggleSettings,
                child: Container(
                  color: Colors.black38,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: MapSettingsPanel(onClose: _toggleSettings),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
