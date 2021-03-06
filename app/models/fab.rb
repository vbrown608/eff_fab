class Fab < ActiveRecord::Base
  has_attached_file :gif_tag,
    styles: { medium: "300x300>", thumb: "100x100>" },
    default_url: "/images/:style/missing.png"

  validates_attachment_content_type :gif_tag, content_type: /\Aimage\/.*\Z/

  default_scope { order('period DESC') }

  belongs_to :user
  has_many :notes
  has_many :forward, -> { where(forward: true) }, class_name: "Note"
  has_many :backward, -> { where(forward: false) }, class_name: "Note"


  accepts_nested_attributes_for :notes, reject_if: :all_blank, :allow_destroy => true

  after_initialize :setup_children


  def self.find_or_build_this_periods_fab
    fab_attrs = {period: get_start_of_current_fab_period..get_start_of_current_fab_period+6.days}
    self.where(fab_attrs).first || self.new(period: get_start_of_current_fab_period)
  end

  # If it's Thursday, should return the date of two mondays ago
  # if it's Friday, it should return the monday of the current week!!!
  def self.get_start_of_current_fab_period
    # should we show the old fab or a new one
    start_day = if within_edit_period_of_old_fab?
      # return the date for the prior week's fab entry so...
      # (go back 7 days, then go forward until the first Monday) (potentially jumping back more than 7 days!)
      (DateTime.now.midnight - 2.week - 1.day)
    else
      # return the date for the current weeks fab entry so...
      # (go back 7 days from now, then go forward until the first Monday)
      (DateTime.now.midnight - 1.week - 1.day)
    end

    start_day = advance_to_the_next_period_beginning(start_day)
  end

  def to_s
    forwards = forward.collect {|n| n.body}.join(", ")
    backwards = backward.collect {|n| n.body}.join(", ")
    " Backwards: #{backwards} \n Forwards: #{forwards}"
  end

  def setup_children
    if notes.empty?
      3.times { notes.build(forward: true) }
      3.times { notes.build(forward: false) }
    end
  end

  # depricated
  # This method presents to the view what period this FAB is for
  # Returns something like "February 8, 2016 - February 12, 2016"
  def display_back_time_span
    display_time_span(period)
  end
  # depricated
  def display_forward_time_span
    display_time_span(period + 1.week)
  end

  # Returns "Week of March 28th, 2016"
  def display_back_start_day
    display_start_day_of_week(period)
  end

  def display_forward_start_day
    display_start_day_of_week(period + 1.week)
  end

  def display_date_for_header
    self.period.strftime("%b %e") + "-" + (self.period + 4.days).strftime("%e")
  end

  # this function can be used as a seek forward and will skip blank fabs
  def previous_fab
    self.user.fabs.where('period < ?', self.period).first
  end

  # this function can be used as a seek forward
  def next_fab
    fab = self.user.fabs.where('period > ?', self.period).last
  end

  # this function tries to return the exact next fab for the user, or returns nil
  def exactly_next_fab(include_hypothetical_fab = true)
    fab = self.user.fabs.where(period: period+1.week-1.day..period+2.weeks-1.day).last
    fab = self.user.fabs.build(period: period+1.week) if include_hypothetical_fab and fab.nil?
    fab
  end

  # this function tries to return the exact previous fab for the user, or returns nil
  def exactly_previous_fab(include_hypothetical_fab = true)
    fab = self.user.fabs.where(period: period+1.day-2.week..period+1.day-1.week).last
    fab = self.user.fabs.build(period: period-1.week) if include_hypothetical_fab and fab.nil?
    fab
  end


  # returns an array of two, indicating true or false whether there's a previos
  # or next fab relative to the fab_id supplied
  def which_neighbor_fabs_exist?
    [!self.previous_fab.nil?, !self.next_fab.nil?]
  end

  def self.advance_to_the_next_period_beginning(given_day)
    desired_wday = DateTime.parse(ENV['fab_starting_day']).wday
    current_date_progress = given_day

    until current_date_progress.wday == desired_wday do
      current_date_progress = current_date_progress.advance days: 1
    end

    current_date_progress
  end

  private

    # Old fab refers to a FAB which was created 2 mondays ago, not the most
    # recent monday.
    # If it's mon, tuesday, wed, thrs, then jump back 2 mondays
    # else if it's fri, sat, sun, mon, jump back 1 single monday
    def self.within_edit_period_of_old_fab?
      week_of_days = [0,1,2,3,4,5,6]

      # if it's thrs
      starting_day_of_week = DateTime.parse(ENV['fab_starting_day']).wday

      # we need to rotate the week so it begins with the first day of the fab period
      # which will allow us to easily sort through which days we need to jump
      # backward by 2 mondays instead of just one
      rotated_week = week_of_days.rotate(week_of_days.find_index(starting_day_of_week)) # => 1

      jump_back_two_monday_days = rotated_week[0..3]
      # jump_back_single_monday_days = rotated_week[4..-1]

      if jump_back_two_monday_days.include?(DateTime.now.wday)
        true
      else
        false
      end
    end

    # depricated, grace_period doesn't need to be used... use Fab#within_edit_period_of_old_fab? instead
    # If Fab start day in Monday, and the fab due day is Monday, with a due time of 5PM...
    # the grace period shall be defined to Mondays from 0:00 - 16:59
    def self.within_grace_period?
      we_are_within_the_grace_period_of_days? and we_are_within_the_grace_period_of_hours?
    end

    def self.we_are_within_the_grace_period_of_days?
      starting_day_of_week = DateTime.parse(ENV['fab_starting_day']).wday
      grace_period_days = DateTime.parse(ENV['fab_due_day']).wday - starting_day_of_week

      (DateTime.now.wday - starting_day_of_week) <= grace_period_days and DateTime.now.wday >= starting_day_of_week
    end

    def self.we_are_within_the_grace_period_of_hours?
      grace_period_hours = DateTime.parse(ENV['fab_due_time']).hour
      DateTime.now.hour < grace_period_hours
    end



    # depricated due to design decision
    def display_time_span(p_start)
      p_end = p_start + 4.days
      s = p_start.strftime("'%y: %b %e - ")
      s += p_end.strftime("%b %e")
      s
    end

    def display_start_day_of_week(p_start)
      ist_of_month = p_start.strftime("%e").to_i.ordinalize
      p_start.strftime("Week of %B #{ist_of_month}, %Y")
    end

end
