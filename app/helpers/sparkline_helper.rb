# app/helpers/sparkline_helper.rb

module SparklineHelper
  # Generate SVG sparkline for post metrics
  # Uses step interpolation to show periods where metrics didn't change
  def post_metrics_sparkline(post, width: 80, height: 25)
    metrics = post.post_metrics.order(:recorded_at).limit(100).to_a

    return sparkline_placeholder(width, height) if metrics.empty?

    # Extract data points
    data_points = metrics.map { |m| [m.recorded_at, m.total_interactions] }

    # Generate SVG path using step interpolation
    svg_path = generate_sparkline_path(data_points, width, height)

    # Calculate color based on average performance
    color = sparkline_color(post)

    # Build SVG
    content_tag(:svg,
                class: "sparkline inline-block",
                width: width,
                height: height,
                viewBox: "0 0 #{width} #{height}",
                preserveAspectRatio: "none") do
      concat tag.defs do
        tag.linearGradient(id: "sparkline-gradient-#{post.id}", x1: "0%", y1: "0%", x2: "0%", y2: "100%") do
          concat tag.stop(offset: "0%", style: "stop-color:#{color};stop-opacity:0.3")
          concat tag.stop(offset: "100%", style: "stop-color:#{color};stop-opacity:0.05")
        end
      end
      concat tag.path(
        d: svg_path[:area],
        fill: "url(#sparkline-gradient-#{post.id})",
        class: "sparkline-area"
      )
      concat tag.path(
        d: svg_path[:line],
        fill: "none",
        stroke: color,
        stroke_width: "1.5",
        class: "sparkline-line"
      )
    end
  end

  private

  # Generate SVG path with step interpolation
  def generate_sparkline_path(data_points, width, height)
    return { line: "", area: "" } if data_points.empty?

    # Find min and max for scaling
    values = data_points.map { |_, v| v }
    min_value = values.min
    max_value = values.max
    value_range = max_value - min_value

    # Avoid division by zero
    value_range = 1 if value_range.zero?

    # Calculate time range
    timestamps = data_points.map { |t, _| t }
    min_time = timestamps.min
    max_time = timestamps.max
    time_range = max_time - min_time
    time_range = 1 if time_range.zero?

    # Generate points with step interpolation
    line_commands = []
    area_commands = []

    data_points.each_with_index do |(timestamp, value), index|
      # Calculate x position (linear time scale)
      time_offset = timestamp - min_time
      x = (time_offset.to_f / time_range * width).round(2)

      # Calculate y position (inverted because SVG y increases downward)
      normalized_value = (value - min_value).to_f / value_range
      y = (height - (normalized_value * height * 0.9) - (height * 0.05)).round(2)

      if index == 0
        # Start of path
        line_commands << "M#{x},#{y}"
        area_commands << "M#{x},#{height}"
        area_commands << "L#{x},#{y}"
      else
        # Step interpolation: horizontal line, then vertical
        prev_x = line_commands.last.split(',').first.split(/[ML]/).last.to_f

        # Horizontal line at previous y value
        line_commands << "L#{x},#{line_commands.last.split(',').last}"
        # Vertical line to new y value
        line_commands << "L#{x},#{y}"

        # Same for area
        area_commands << "L#{x},#{area_commands.last.split(',').last}"
        area_commands << "L#{x},#{y}"
      end
    end

    # Close area path
    last_x = data_points.last[0]
    time_offset = last_x - min_time
    x = (time_offset.to_f / time_range * width).round(2)
    area_commands << "L#{x},#{height}"
    area_commands << "Z"

    {
      line: line_commands.join(' '),
      area: area_commands.join(' ')
    }
  end

  # Determine sparkline color based on post performance
  def sparkline_color(post)
    score = post.overperformance_score_cache

    return '#9CA3AF' if score.nil? # Gray for no score

    case score
    when 0..50
      '#EF4444' # Red
    when 50..100
      '#F59E0B' # Yellow/Orange
    when 100..150
      '#3B82F6' # Blue
    else
      '#10B981' # Green
    end
  end

  # Placeholder for posts with no metrics
  def sparkline_placeholder(width, height)
    content_tag(:svg,
                class: "sparkline inline-block opacity-30",
                width: width,
                height: height,
                viewBox: "0 0 #{width} #{height}") do
      tag.line(
        x1: 0,
        y1: height / 2,
        x2: width,
        y2: height / 2,
        stroke: "#D1D5DB",
        stroke_width: "1",
        stroke_dasharray: "2,2"
      )
    end
  end
end
