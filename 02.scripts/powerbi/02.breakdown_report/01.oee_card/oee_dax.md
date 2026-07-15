oee_card =

// ---------------------------------------------------------
// 🟩 [STEP 1] - DATA CONNECTED TO THE MODEL (OEE)
// ---------------------------------------------------------

-- OEE weighted by planned_production_time (the correct way to aggregate OEE).
-- Returns a fraction (e.g. 0.6848). We multiply by 100 for the card's 0-100 scale.
VAR _oee_current =
    DIVIDE (
        SUMX ( fact_status_table_dev, fact_status_table_dev[oee] * fact_status_table_dev[planned_production_time] ),
        SUM ( fact_status_table_dev[planned_production_time] )
    )

VAR raw_metric_value            = _oee_current * 100  -- Real OEE on the 0-100 scale
VAR card_title                  = "OEE"              -- Main title shown on the card

VAR status_text_good            = "Excellent"        -- Text shown when the target is met
VAR status_text_critical        = "Critical"         -- Text shown when the target is NOT met

VAR percent_suffix              = "%"                -- Suffix shown on the central number
VAR score_divisor               = "/100"             -- Supporting text below the title

VAR target_value                = 85                 -- Target/goal (KPI) in %

// ---------------------------------------------------------
// 🟨 [STEP 2] - CUSTOMIZE THE DESIGN (OPTIONAL)
// ---------------------------------------------------------

-- Fonts (consistent with performance_card)
VAR font_title                  = "'Segoe UI', sans-serif"   -- Font for title and text
VAR font_number                 = "'Calibri', sans-serif"    -- Font for all numbers

-- Colors
VAR color_text_primary          = "#1E293B"          -- Main number color
VAR color_text_label            = "#000000"          -- Card title color
VAR color_success               = "#36B396"          -- Color when target is met (green)
VAR color_danger                = "#E63946"          -- Color when target is NOT met (red)
VAR color_track                 = "#F1F5F9"          -- Background circle (track) color
VAR color_target                = "#0F172A"          -- Target line color

-- Typography
VAR size_font_title             = "13px"             -- Card title size (OEE)
VAR size_font_value             = "24px"             -- Central number size (e.g. 68%)
VAR size_font_badge             = "8px"              -- Status badge text size (e.g. Critical)
VAR size_font_fraction          = "13px"             -- Size of the number above the badge (e.g. 68/100)

-- Dimensions
VAR radius_chart                = 30                 -- Score circle radius
VAR stroke_width                = 8                  -- Ring stroke width
VAR canvas_height               = 180                -- Total card height
VAR canvas_width                = 270                -- Total card width
VAR score_width                 = 120                -- Score area width
VAR score_height                = 120                -- Score area height

-- Target line (KPI)
VAR target_stroke               = 2                  -- Target line thickness
VAR target_overhang             = 2                  -- How far the line overhangs the ring (px) each side

-- SVG geometry (computed so the ring is never clipped)
-- The viewBox is sized to fit radius + half the stroke, with margin.
VAR _half_stroke                = stroke_width / 2
VAR _center                     = radius_chart + _half_stroke + 6   -- center with 6px margin
VAR _viewbox_size               = _center * 2                       -- viewBox side (square)
VAR center_txt                  = SUBSTITUTE ( FORMAT ( _center, "0" ), ",", "." )
VAR viewbox_txt                 = "0 0 " & SUBSTITUTE ( FORMAT ( _viewbox_size, "0" ), ",", "." ) & " " & SUBSTITUTE ( FORMAT ( _viewbox_size, "0" ), ",", "." )

-- Spacing
VAR pad_top                     = "0px"              -- Inner top padding
VAR pad_bottom                  = "0px"              -- Inner bottom padding
VAR pad_left                    = "16px"             -- Inner left padding
VAR pad_right                   = "16px"             -- Inner right padding
VAR gap_main                    = "12px"             -- Space between chart and text
VAR gap_text                    = "2px"              -- Vertical space between text lines


// ---------------------------------------------------------
// 🚫 SYSTEM LOGIC (DO NOT EDIT BELOW)
// ---------------------------------------------------------

VAR metric_normalized =
    MAX ( 0, MIN ( 100, raw_metric_value ) )

VAR target_normalized =
    MAX ( 0, MIN ( 100, target_value ) )

-- Status based ONLY on the target: green if the target is met, red otherwise.
VAR target_met =
    metric_normalized >= target_normalized

VAR color_status =
    IF ( target_met, color_success, color_danger )

VAR status_text =
    IF ( target_met, status_text_good, status_text_critical )

VAR circumference =
    2 * 3.14159 * radius_chart

VAR dash_offset =
    circumference * ( 1 - ( metric_normalized / 100 ) )

VAR circ_txt =
    SUBSTITUTE ( FORMAT ( circumference, "0.00" ), ",", "." )

VAR offset_txt =
    SUBSTITUTE ( FORMAT ( dash_offset, "0.00" ), ",", "." )

-- =====================
-- TARGET VALUES (STRAIGHT RADIAL LINE)
-- =====================

-- Target angle in radians (0% at the top, clockwise because of rotate(-90deg))
VAR _ang_target = ( target_normalized / 100 ) * 2 * 3.14159

-- Inner and outer radii of the line (crosses the ring band, with overhang)
VAR _r_inner = radius_chart - ( stroke_width / 2 ) - target_overhang
VAR _r_outer = radius_chart + ( stroke_width / 2 ) + target_overhang

-- Because the SVG has rotate(-90deg), we use the angle directly: x = center + r*cos, y = center + r*sin
VAR _x1 = _center + _r_inner * COS ( _ang_target )
VAR _y1 = _center + _r_inner * SIN ( _ang_target )
VAR _x2 = _center + _r_outer * COS ( _ang_target )
VAR _y2 = _center + _r_outer * SIN ( _ang_target )

VAR x1_txt = SUBSTITUTE ( FORMAT ( _x1, "0.00" ), ",", "." )
VAR y1_txt = SUBSTITUTE ( FORMAT ( _y1, "0.00" ), ",", "." )
VAR x2_txt = SUBSTITUTE ( FORMAT ( _x2, "0.00" ), ",", "." )
VAR y2_txt = SUBSTITUTE ( FORMAT ( _y2, "0.00" ), ",", "." )

VAR html_final =
"<!DOCTYPE html>
<html>
<head>
<style>
*{box-sizing:border-box}
::-webkit-scrollbar{width:0;height:0}
html,body{
    margin:0;
    padding:0;
    width:" & FORMAT ( canvas_width, "0" ) & "px;
    height:" & FORMAT ( canvas_height, "0" ) & "px;
    background:transparent;
    overflow:hidden;
}
.card-container{
    font-family:" & font_title & ";
    width:" & FORMAT ( canvas_width, "0" ) & "px;
    height:" & FORMAT ( canvas_height, "0" ) & "px;
    display:flex;
    align-items:center;
    background:transparent;
    padding:" & pad_top & " " & pad_right & " " & pad_bottom & " " & pad_left & ";
}
.header-main{
    height:100%;
    width:100%;
    display:flex;
    align-items:center;
    gap:" & gap_main & ";
}
.score-container{
    position:relative;
    width:" & FORMAT ( score_width, "0" ) & "px;
    height:" & FORMAT ( score_height, "0" ) & "px;
    flex-shrink:0;
}
.score-svg{
    transform:rotate(-90deg);
    width:" & FORMAT ( score_width, "0" ) & "px;
    height:" & FORMAT ( score_height, "0" ) & "px;
}
.score-bg{
    fill:none;
    stroke:" & color_track & ";
    stroke-width:" & stroke_width & ";
}
.score-fill{
    fill:none;
    stroke:" & color_status & ";
    stroke-width:" & stroke_width & ";
    stroke-linecap:round;
    stroke-dasharray:" & circ_txt & ";
    stroke-dashoffset:" & offset_txt & ";
}
.score-meta{
    stroke:" & color_target & ";
    stroke-width:" & FORMAT ( target_stroke, "0" ) & ";
    stroke-linecap:round;
}
.score-text-inside{
    position:absolute;
    top:50%;
    left:50%;
    transform:translate(-50%,-50%);
    font-family:" & font_number & ";
    font-weight:800;
    font-size:" & size_font_value & ";
    color:" & color_text_primary & ";
}
.score-info-text{
    display:flex;
    flex-direction:column;
    justify-content:center;
    gap:" & gap_text & ";
    min-width:0;
    flex:1;
    overflow:hidden;
}
.main-title{
    font-family:" & font_title & ";
    font-size:" & size_font_title & ";
    font-weight:700;
    color:" & color_text_label & ";
    white-space:nowrap;
    overflow:hidden;
    text-overflow:ellipsis;
}
.score-fraction{
    font-family:" & font_number & ";
    font-size:" & size_font_fraction & ";
    font-weight:800;
    color:" & color_text_primary & ";
    line-height:1.1;
}
.badge-score{
    font-family:" & font_title & ";
    background:" & color_status & "15;
    color:" & color_status & ";
    padding:2px 6px;
    border-radius:4px;
    font-size:" & size_font_badge & ";
    font-weight:800;
    text-transform:uppercase;
    width:fit-content;
    line-height:1;
}
</style>
</head>
<body>
<div class='card-container'>
    <div class='header-main'>
        <div class='score-container'>
            <svg class='score-svg' viewBox='" & viewbox_txt & "'>
                <circle cx='" & center_txt & "' cy='" & center_txt & "' r='" & radius_chart & "' class='score-bg'/>
                <circle cx='" & center_txt & "' cy='" & center_txt & "' r='" & radius_chart & "' class='score-fill'/>
                <line x1='" & x1_txt & "' y1='" & y1_txt & "' x2='" & x2_txt & "' y2='" & y2_txt & "' class='score-meta'/>
            </svg>
            <div class='score-text-inside'>" & FORMAT ( metric_normalized, "0" ) & percent_suffix & "</div>
        </div>
        <div class='score-info-text'>
            <span class='main-title'>" & card_title & "</span>
            <div class='score-fraction'>" & FORMAT ( metric_normalized, "0" ) & score_divisor & "</div>
            <div class='badge-score'>" & status_text & "</div>
        </div>
    </div>
</div>
</body>
</html>"

RETURN
    html_final
