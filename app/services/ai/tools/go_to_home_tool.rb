class Ai::Tools::GoToHomeTool < Ai::Tools::BaseTool
  def name
    "go_to_home"
  end

  def description
    "Navigate user to home page"
  end

  def call(input = {})
    success(
      data: {
        action: "navigate",
        url: "/"

      },
      message: "Navigating to home page"
    )
  end
end
