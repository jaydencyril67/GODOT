#!/usr/bin/env python3
"""Patch the pinned godot-3dtiles camera controller with native Android touch input."""
from pathlib import Path
root = Path("vendor/godot-3dtiles/src")
cpp_path, h_path = root / "GlobeCameraController.cpp", root / "GlobeCameraController.h"
cpp, header = cpp_path.read_text(), h_path.read_text()
occluder_header = root / "core/math/EllipsoidalOccluder.h"
occluder = occluder_header.read_text()
tile_layer_cpp = root / "GlobeTileLayer.cpp"
tile_layer = tile_layer_cpp.read_text()

def once(src, old, new, label):
    n = src.count(old)
    if n != 1: raise SystemExit(f"{label}: expected one anchor, found {n}")
    return src.replace(old, new, 1)

cpp = once(cpp, '#include "godot_cpp/classes/input_event_mouse_motion.hpp"\n',
    '#include "godot_cpp/classes/input_event_mouse_motion.hpp"\n#include "godot_cpp/classes/input_event_screen_drag.hpp"\n#include "godot_cpp/classes/input_event_screen_touch.hpp"\n', "touch includes")
cpp = once(cpp, '    using godot::InputEventMouseMotion;\n',
    '    using godot::InputEventMouseMotion;\n    using godot::InputEventScreenDrag;\n    using godot::InputEventScreenTouch;\n', "touch aliases")

start = cpp.index("    void GlobeCameraController::_unhandled_input")
end = cpp.index("\n    }\n\n} // namespace tiles3d", start) + len("\n    }")
body = r'''    void GlobeCameraController::_unhandled_input( const Ref<InputEvent> &p_event )
    {
        // Touch input is direct-manipulation: one finger orbits; two fingers pinch.
        // Pinch updates the camera immediately, so zoom stops when the fingers stop.
        if ( const InputEventScreenTouch *touch =
                 Object::cast_to<InputEventScreenTouch>( p_event.ptr() ) )
        {
            const int index = touch->get_index();
            if ( touch->is_pressed() )
            {
                if ( touch_index_a_ < 0 )
                {
                    touch_index_a_ = index;
                    touch_position_a_ = touch->get_position();
                }
                else if ( touch_index_b_ < 0 && index != touch_index_a_ )
                {
                    touch_index_b_ = index;
                    touch_position_b_ = touch->get_position();
                    touch_pinch_distance_ =
                        static_cast<double>( ( touch_position_b_ - touch_position_a_ ).length() );
                }
                fly_active_ = false;
                wheel_animating_ = false;
                last_drag_dx_ = 0.0;
                last_drag_dy_ = 0.0;
            }
            else
            {
                if ( index == touch_index_a_ )
                {
                    touch_index_a_ = touch_index_b_;
                    touch_position_a_ = touch_position_b_;
                    touch_index_b_ = -1;
                }
                else if ( index == touch_index_b_ )
                {
                    touch_index_b_ = -1;
                }
                touch_pinch_distance_ = 0.0;
                last_drag_dx_ = 0.0;
                last_drag_dy_ = 0.0;
            }
            return;
        }

        if ( const InputEventScreenDrag *drag =
                 Object::cast_to<InputEventScreenDrag>( p_event.ptr() ) )
        {
            const int index = drag->get_index();
            const Vector2 position = drag->get_position();
            if ( index == touch_index_a_ )
            {
                const Vector2 delta = position - touch_position_a_;
                touch_position_a_ = position;
                if ( touch_index_b_ < 0 && delta.length_squared() > 0.0f )
                {
                    fly_active_ = false;
                    wheel_animating_ = false;
                    apply_orbit_drag( delta.x, delta.y );
                }
            }
            else if ( index == touch_index_b_ )
            {
                touch_position_b_ = position;
            }

            // Either finger may move during a pinch; always measure the pair after
            // updating the moved pointer, rather than only when finger B moves.
            if ( touch_index_a_ >= 0 && touch_index_b_ >= 0 )
            {
                const double previous = touch_pinch_distance_;
                const double current =
                    static_cast<double>( ( touch_position_b_ - touch_position_a_ ).length() );
                touch_pinch_distance_ = current;
                if ( previous > 1.0 && current > 1.0 && std::abs( current - previous ) > 0.01 )
                {
                    fly_active_ = false;
                    wheel_animating_ = false;
                    const double minimum_distance = math::kWgs84MeanRadius + kMinCameraHeight;
                    set_distance( clampd( get_distance() * previous / current,
                                          minimum_distance, max_distance() ) );
                }
            }
            return;
        }

        const InputEventMouseButton *button = Object::cast_to<InputEventMouseButton>( p_event.ptr() );
        const InputEventMouseMotion *motion =
            Object::cast_to<InputEventMouseMotion>( p_event.ptr() );
        const bool dragging = left_dragging_ || right_dragging_;
        if ( button != nullptr ||
             ( motion != nullptr && dragging && motion->get_relative().length_squared() > 0.0f ) )
            fly_active_ = false;

        if ( button != nullptr )
        {
            if ( button->get_button_index() == MOUSE_BUTTON_LEFT )
            {
                if ( button->is_pressed() )
                {
                    left_dragging_ = true;
                    last_mouse_position_ = button->get_position();
                    mouse_down_time_ = Time::get_singleton()->get_ticks_msec() / 1000.0;
                    wheel_animating_ = false;
                }
                else
                {
                    left_dragging_ = false;
                    mouse_up_time_ = Time::get_singleton()->get_ticks_msec() / 1000.0;
                }
            }
            else if ( button->get_button_index() == MOUSE_BUTTON_RIGHT )
            {
                if ( button->is_pressed() )
                {
                    right_dragging_ = true;
                    last_mouse_position_ = button->get_position();
                    wheel_animating_ = false;
                    tilt_pivot_valid_ = tilt_pivot( tilt_pivot_ecef_ );
                    tilt_looking_ = !tilt_pivot_valid_;
                }
                else
                {
                    right_dragging_ = false;
                    tilt_pivot_valid_ = false;
                    tilt_looking_ = false;
                }
            }
            else if ( button->is_pressed() &&
                      ( button->get_button_index() == MOUSE_BUTTON_WHEEL_UP ||
                        button->get_button_index() == MOUSE_BUTTON_WHEEL_DOWN ) )
            {
                const bool zoom_in = button->get_button_index() == MOUSE_BUTTON_WHEEL_UP;
                if ( zoom_in && camera_height_above_ellipsoid() < kWheelMinFocusDistance ) return;
                const bool fresh_burst = !wheel_animating_;
                math::Vec3 focus_ecef{};
                const godot::Viewport *viewport = get_viewport();
                const Vector2 screen_size = viewport != nullptr
                    ? viewport->get_visible_rect().size : Vector2( 1920.0f, 1080.0f );
                if ( pick_ellipsoid_point( screen_size * 0.5f, focus_ecef ) )
                {
                    wheel_focus_ecef_ = focus_ecef;
                    wheel_focus_valid_ = true;
                }
                else if ( fresh_burst ) wheel_focus_valid_ = false;
                const Vector3 focus = wheel_focus_parent();
                const Vector3 radial_vector = get_position() - focus;
                const double focus_distance = static_cast<double>( radial_vector.length() );
                if ( focus_distance < 1e-6 ) return;
                wheel_radial_direction_ = radial_vector / radial_vector.length();
                if ( !inertia_enabled_ )
                {
                    const double step = ( zoom_in ? -1.0 : 1.0 ) * kLogDistancePerNotch * zoom_speed_scale_;
                    const double next = std::max( focus_distance * std::exp( step ), kWheelMinFocusDistance );
                    Vector3 next_position = focus + wheel_radial_direction_ * static_cast<float>( next );
                    const Vector3 pivot = resolve_pivot();
                    const double centre_distance = static_cast<double>( ( next_position - pivot ).length() );
                    if ( centre_distance > max_distance() )
                        next_position = pivot + ( next_position - pivot ) * static_cast<float>( max_distance() / centre_distance );
                    set_position( next_position );
                    enforce_camera_above_ellipsoid();
                    sync_distance_from_camera();
                    return;
                }
                wheel_log_distance_ = std::log( std::max( focus_distance, kWheelMinFocusDistance ) );
                if ( !wheel_animating_ ) { wheel_log_velocity_ = 0.0; wheel_animating_ = true; }
                const double direction = zoom_in ? -1.0 : 1.0;
                const double damping = std::max( zoom_inertia_damping_, 0.1 );
                const double max_velocity = kMaxFlickLogTravel * damping;
                wheel_log_velocity_ = clampd( wheel_log_velocity_ + direction * kLogDistancePerNotch * damping,
                                              -max_velocity, max_velocity );
                wheel_last_time_ = Time::get_singleton()->get_ticks_msec() / 1000.0;
            }
            return;
        }

        if ( motion == nullptr ) return;
        const Vector2 position = motion->get_position();
        const double dx = position.x - last_mouse_position_.x;
        const double dy = position.y - last_mouse_position_.y;
        last_mouse_position_ = position;
        if ( left_dragging_ )
        {
            last_drag_dx_ = dx;
            last_drag_dy_ = dy;
            apply_orbit_drag( dx, dy );
        }
        else if ( right_dragging_ ) apply_tilt_drag( dx, dy );
    }'''
cpp = cpp[:start] + body + cpp[end:]
header = once(header, '        godot::Vector2 last_mouse_position_;\n',
    '        godot::Vector2 last_mouse_position_;\n'
    '        int touch_index_a_ = -1;\n        int touch_index_b_ = -1;\n'
    '        godot::Vector2 touch_position_a_;\n        godot::Vector2 touch_position_b_;\n'
    '        double touch_pinch_distance_ = 0.0;\n', "touch state")
cpp_path.write_text(cpp)
h_path.write_text(header)
occluder = once(occluder, "/// @param west,south,east,north the rectangle, radians. Its centre drives the\n", "/// @param west longitude of the western edge, radians.\n    /// @param south latitude of the southern edge, radians.\n    /// @param east longitude of the eastern edge, radians.\n    /// @param north latitude of the northern edge, radians. Its centre drives the\n", "Android Clang documentation warning")
occluder_header.write_text(occluder)
tile_layer = once(tile_layer, "        constexpr int kFramingFrames = 5;\n", "        [[maybe_unused]] constexpr int kFramingFrames = 5;\n", "Android release-only framing constant")
tile_layer = once(tile_layer, "        constexpr int kFramingFrameCap = 600;\n", "        [[maybe_unused]] constexpr int kFramingFrameCap = 600;\n", "Android release-only framing cap")
tile_layer_cpp.write_text(tile_layer)
print("Native Android touch controls and Android Clang/release compatibility patches applied.")
