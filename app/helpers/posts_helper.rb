# app/helpers/posts_helper.rb

module PostsHelper
  def sort_link(column, label)
    direction = params[:sort] == column && params[:direction] == 'desc' ? 'asc' : 'desc'

    link_to posts_path(
      sort: column,
      direction: direction,
      search: params[:search],
      post_type: params[:post_type],
      date_from: params[:date_from],
      date_to: params[:date_to],
      min_interactions: params[:min_interactions],
      min_performance: params[:min_performance]
    ), class: "flex items-center hover:text-gray-700" do
      concat label
      if params[:sort] == column
        concat content_tag(:svg, class: "w-4 h-4 ml-1", fill: "currentColor", viewBox: "0 0 20 20") do
          if params[:direction] == 'asc'
            content_tag(:path, nil,
                        d: "M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z")
          else
            content_tag(:path, nil,
                        d: "M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z")
          end
        end
      end
    end
  end
end
