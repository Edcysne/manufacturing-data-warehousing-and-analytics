availability_card =

// ---------------------------------------------------------
// 🟩 [STEP 1] - DATA CONNECTED TO THE MODEL (OEE AVAILABILITY)
// ---------------------------------------------------------

-- Availability weighted by run_time (consistent with the OEE calculation).
VAR _value_current =
    DIVIDE (
        SUMX ( fact_status_table_dev, fact_status_table_dev[availability] * fact_status_table_dev[run_time] ),
        SUM ( fact_status_table_dev[run_time] )
    )

VAR value_num                      = _value_current        -- Actual: current availability (e.g. 0.82 = 82%)
VAR target_num                     = 0.85              -- Fixed default target of 85%
VAR label_txt                      = "Availability"             -- Main card title

-- Secondary indicator: distance to the target
-- (negative = below target; positive = above target)
VAR dist_target                    = value_num - target_num

VAR prefix_target                  = "Target: "          -- Prefix shown before the target value
VAR suffix_dist                    = " to target"        -- Suffix for the secondary indicator


// ---------------------------------------------------------
// 🟨 [STEP 2] - CUSTOMIZE THE DESIGN (OPTIONAL)
// ---------------------------------------------------------

-- Fonts
VAR font_title                     = "'Segoe UI', sans-serif"   -- Title font (Segoe UI Bold via font-weight)
VAR font_text                      = "'Segoe UI', sans-serif"   -- Text font (target, etc.)
VAR font_number                    = "'Calibri', sans-serif"    -- Font for all numbers

-- Main colors
VAR color_text_primary             = "#1E293B"           -- Main value color
VAR color_text_label               = "#000000"           -- Title color
VAR color_text_target              = "#64748B"           -- Target text color
VAR color_track_empty              = "#D1D5DB"           -- Empty bar background color

-- Status colors
VAR color_status_critical          = "#EF4444"           -- Critical status color (red)
VAR color_status_good              = "#22C55E"           -- Good status color (green)

-- Target line colors (darker accent of the status)
VAR color_target_line_critical     = "#B91C1C"           -- Target line (dark red accent)
VAR color_target_line_good         = "#15803D"           -- Target line (dark green accent)

-- Secondary badge colors
VAR bg_badge_critical              = "#000000"           -- Negative badge background
VAR bg_badge_good                  = "#F0FDF4"           -- Positive badge background
VAR border_badge_critical          = "#FCA5A5"           -- Negative badge border (unused: border follows text)
VAR border_badge_good              = "#86EFAC"           -- Positive badge border (unused: border follows text)
VAR text_badge_critical            = "#B91C1C"           -- Negative badge text/border color
VAR text_badge_good                = "#166534"           -- Positive badge text/border color

-- Bar fill colors
VAR fill_bar_critical              = "#FEE2E2"           -- Critical bar fill (red)
VAR fill_bar_good                  = "#DCFCE7"           -- Good bar fill (green)

-- Typography
VAR size_font_title                = "13px"              -- Title size
VAR size_font_value                = "24px"              -- Main value size
VAR size_font_target               = "8.5px"             -- Target text size
VAR size_font_badge                = "8px"               -- Secondary badge size

-- Components
VAR bar_svg_height                 = 15                  -- SVG bar height
VAR badge_radius                   = "3px"               -- Badge corner rounding
VAR bar_radius                     = "1px"               -- Bar corner rounding
VAR target_line_stroke             = 1.5                 -- Target line thickness

-- Dimensions and spacing
VAR canvas_height                  = 125                 -- Total card height
VAR canvas_width                   = 246                 -- Total card width
VAR pad_top                        = "0px"               -- Inner top padding
VAR pad_bottom                     = "0px"               -- Inner bottom padding
VAR pad_left                       = "20px"              -- Inner left padding
VAR pad_right                      = "20px"              -- Inner right padding


// ---------------------------------------------------------
// 🚫 SYSTEM LOGIC (DO NOT EDIT BELOW)
// ---------------------------------------------------------

VAR icon_arrow_up =
    UNICHAR ( 8593 )

VAR icon_arrow_down =
    UNICHAR ( 8595 )

-- Bar fill: capped at 100% (max ceiling). The full bar represents 100%.
VAR pct_bar =
    MIN ( 1, MAX ( 0, value_num ) )

-- Bar state: red if below target OR above 100%.
VAR is_red =
    OR ( value_num < target_num, value_num > 1 )

-- X position of the target line within the bar (0..220, where 220 = 100%).
VAR pos_target_line =
    ROUND ( 220 * MIN ( 1, MAX ( 0, target_num ) ), 0 )

VAR value_txt =
    FORMAT ( value_num, "0.0%" )

VAR target_txt =
    prefix_target & FORMAT ( target_num, "0.0%" )

VAR style_badge_base =
    "display:inline-flex;align-items:center;justify-content:center;border:1px solid @@BOR@@;border-radius:" &
        badge_radius &
        ";padding:1px 4px;font-size:" &
        size_font_badge &
        ";font-weight:600;white-space:nowrap;height:16px;font-family:" & font_number & ";background:@@BG@@;color:@@TXT@@;"

-- Secondary badge: distance in percentage points to/beyond the target.
-- The border and text use the SAME color (dark accent), according to status.
VAR badge_mom =
    VAR v_txt =
        IF ( dist_target >= 0, text_badge_good, text_badge_critical )
    VAR v_bor = v_txt
    VAR v_bg =
        IF ( dist_target >= 0, bg_badge_good, bg_badge_critical )
    VAR v_lbl =
        IF ( dist_target > 0, icon_arrow_up & " +", icon_arrow_down & " -" ) &
        FORMAT ( ABS ( dist_target ), "0.0%" ) &
        suffix_dist
    RETURN
        "<div style='" &
            SUBSTITUTE (
                SUBSTITUTE (
                    SUBSTITUTE ( style_badge_base, "@@BOR@@", v_bor ),
                    "@@BG@@", v_bg
                ),
                "@@TXT@@", v_txt
            ) &
        "'>" &
            v_lbl &
        "</div>"

VAR svg_bar =
    VAR f_eff =
        IF ( is_red, fill_bar_critical, fill_bar_good )
    VAR b_eff =
        IF ( is_red, color_status_critical, color_status_good )
    VAR color_target_line =
        IF ( is_red, color_target_line_critical, color_target_line_good )
    RETURN
        "<svg class='bar-svg' viewBox='0 0 220 15' preserveAspectRatio='none'>" &
            "<rect x='0' y='0' width='220' height='15' rx='" & bar_radius & "' fill='" & color_track_empty & "'/>" &
            "<rect x='0' y='0' width='" & ROUND ( 220 * pct_bar, 0 ) & "' height='15' rx='" & bar_radius & "' fill='" & f_eff & "' stroke='" & b_eff & "' stroke-width='1.5'/>" &
            "<line x1='" & pos_target_line & "' y1='0' x2='" & pos_target_line & "' y2='15' stroke='" & color_target_line & "' stroke-width='" & target_line_stroke & "'/>" &
        "</svg>"

VAR html_final =
    "<!DOCTYPE html><html><head><style>
*{box-sizing:border-box}
::-webkit-scrollbar{width:0;height:0}
html,body{margin:0;padding:0;background:transparent;width:" & canvas_width & "px;height:" & canvas_height & "px;overflow:hidden;}

.card-vendas{font-family:" & font_text & ";width:" & canvas_width & "px;height:" & canvas_height & "px;display:flex;align-items:center;background:transparent;}
.metric-item{
  width:100%;height:100%;
  display:flex;flex-direction:column;justify-content:center;
  padding:" & pad_top & " " & pad_right & " " & pad_bottom & " " & pad_left & ";
  border-right:none;
}

.metric-label{font-family:" & font_title & ";font-size:" & size_font_title & ";font-weight:700;color:" & color_text_label & ";margin-bottom:4px;white-space:nowrap;}
.value-row{display:flex;align-items:center;gap:6px;margin-bottom:5px;}
.metric-value{font-family:" & font_number & ";font-size:" & size_font_value & ";font-weight:800;color:" & color_text_primary & ";white-space:nowrap;}
.bar-wrap{width:100%;height:" & bar_svg_height & "px;margin-bottom:3px;}
.bar-svg{width:100%;height:100%;display:block}
.footer-metrics{display:flex;justify-content:flex-start;font-size:" & size_font_target & ";font-weight:600;color:" & color_text_target & ";}
</style></head><body>
<div class='card-vendas'>
  <div class='metric-item'>
    <div class='metric-label'>" & label_txt & "</div>
    <div class='value-row'>
      <div class='metric-value'>" & value_txt & "</div>
      " & badge_mom & "
    </div>
    <div class='bar-wrap'>" & svg_bar & "</div>
    <div class='footer-metrics'><span>" & target_txt & "</span></div>
  </div>
</div>
</body></html>"

RETURN
    html_final
