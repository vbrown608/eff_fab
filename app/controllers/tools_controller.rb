class ToolsController < ApplicationController
  require File.expand_path('../../../lib/mailers', __FILE__)

  before_action :admin_only, except: [:next_fab, :previous_fab]

  # POST /tools/send_reminders
  def send_reminders
    turbo_remind
  end

  # POST /tools/send_shamings
  def send_shamings
    turbo_report_on_aftermath
  end

  def populate_users
    require File.expand_path('../../../lib/populate_users', __FILE__)
    scrape_procedure
    render text: 'User population complete.'
  end

  def next_fab
    @fab = cycle_fab_by_period(:forward, params)

    @previous_fab_exists, @next_fab_exists = [true, true]
    render '/tools/ajax_forward_back.html.erb', layout: false
  end

  def previous_fab
    @fab = cycle_fab_by_period(:backward, params)

    @previous_fab_exists, @next_fab_exists = [true, true]
    render '/tools/ajax_forward_back.html.erb', layout: false
  end

  # this endpoint creates a model use that's useful for figuring out flaws
  # in the UI
  def create_model_user
    u = User.find_by(email: 'shahid@eff.org')

    # setup long fab
    f = u.fabs.last
    f.backward[0].update_attributes body: "Duis vitae nisi quis enim viverra consequat at et lorem. Morbi in quam ut tellus fermentum iaculis. Nullam erat libero, suscipit eget nullam."
    f.backward[1].update_attributes body: "Fusce malesuada odio orci, sit amet malesuada ipsum laoreet in. Aenean id pretium arcu. Integer volutpat gravida ante, quis rutrum est fermentum vel. Sed tempus justo ipsum, ac accumsan quam facilisis eu. Aliquam mollis euismod eros nullam."
    f.backward[2].update_attributes body: "Quisque quis dignissim dui. Aliquam nec varius neque. Duis vitae lacus amet."

    f.forward[0].update_attributes body: "Dolor sit amet, consectetur adipiscing elit. Nunc neque elit, lacinia eu neque id, venenatis finibus sem. Nunc vel dui ligula. Nullam vitae enim ut ligula euismod tempus vel eget tortor. Vestibulum quis tristique sapien. Nam cursus ac posuere."
    f.forward[1].update_attributes body: "Aenean ornare mi in tellus egestas rhoncus. Quisque quam ante, ultricies at pretium dictum, pulvinar convallis dolor volutpat."
    f.forward[2].update_attributes body: "Dolor sit amet, consectetur adipiscing elit. Nunc neque elit, lacinia eu neque id, venenatis finibus sem. Nunc vel dui ligula. Nullam vitae enim ut ligula euismod tempus vel eget tortor. Vestibulum quis tristique sapien. Nam cursus ac posuere."

    # setup Gif Tag

    f.gif_tag open("http://media2.giphy.com/media/9B5EkgWrF4Rri/giphy.gif")
    f.save

  end


  private

    # pass in a user_id and period in params and it will find the next or previous fab
    def cycle_fab_by_period(direction, params)
      user = User.find(params[:user_id])
      current_fab = find_or_create_base_fab(user, params)
      @fab = (direction == :forward) ? current_fab.exactly_next_fab : current_fab.exactly_previous_fab
    end

    # Sometimes a fab doesn't exist, so we might have to build one to use
    # as a base to find #prev or #next
    def find_or_create_base_fab(user, params)
      t = DateTime.parse(params[:fab_period])
      user.fabs.where(period: t..(t+7)).limit(1).first or
        user.fabs.build(period: t)
    end

end
