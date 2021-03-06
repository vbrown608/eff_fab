include Warden::Test::Helpers
Warden.test_mode!

# Feature: User profile page
#   As a user
#   I want to visit my user profile page
#   So I can see my personal account data
feature 'User fabs page', :devise do

  after(:each) do
    Warden.test_reset!
  end

  # Scenario: User sees own profile
  #   Given I am signed in
  #   When I visit the user profile page
  #   Then I see my own email address
  scenario 'user sees own fab history' do
    log_me_in FactoryGirl.create(:user)
    # below code makes yesterweek's fab
    @me.fabs << FactoryGirl.create(:fab, period: DateTime.now.beginning_of_week(:monday).advance(weeks: -1))
    # below code makes this week's fab
    @me.fabs << FactoryGirl.create(:fab, period: DateTime.now.beginning_of_week(:monday))

    @me.fabs.first.backward.first.update_attributes(body: "I have a note")
    @me.fabs.last.backward.first.update_attributes(body: "I have an old note")

    visit user_fabs_path(@me)

    # Should have an input that contains 'I have a note'
    expect(page).to have_xpath("//input[@value='I have a note']")

    first_fab_header_text = find_all('h4').first.text

    expect(first_fab_header_text).not_to eq @me.fabs.first.display_date_for_header
    expect(page).not_to have_content 'I have a note'
    expect(page).to have_content 'I have an old note'
  end


  # Scenario: User cannot see another user's profile
  #   Given I am signed in
  #   When I visit another user's profile
  #   Then I see an 'access denied' message
  scenario "user can edit own current fab" do
    bring_up_my_fab

    fill_in 'fab_notes_attributes_0_body', :with => 'I did blah in the past'
    fill_in 'fab_notes_attributes_3_body', :with => 'I plan to do blah'

    click_button 'SUBMIT FAB'
    expect(page).to have_content(/Fab was successfully updated\./)
  end

  scenario "user cannot edit the fabs of others" do
    bring_up_anothers_fab_edit

    # expect the page to not have any inputs for editing fab
    expect(page).to_not have_xpath("//input[@value='I have a note']")

    first_fab_note_text = find_all('div.back').first.find_all('ul li').first.text
    first_fab_note_text = strip_unprintable_characters(first_fab_note_text)

    expect(first_fab_note_text).to eq @other.fabs.first.backward.first.body.to_s
  end

  scenario "fabs display the date of the starting day of the current fab" do
    bring_up_my_fab

    # historic fabs display
    first_fab_header_text = find_all('h3').last.text
    expect(first_fab_header_text).to eq @me.fabs.second.display_date_for_header

    # currently editable fabs display
    editable_fab_header_text = find_all('h4').first.text
    editable_fab_header_text_forward = find_all('h4').last.text
    expect(editable_fab_header_text).to eq @me.fabs.first.display_back_start_day
    expect(editable_fab_header_text_forward).to eq @me.fabs.first.display_forward_start_day
  end

end


def log_me_in(me = nil)
  @me = me.nil? ? FactoryGirl.create(:user) : me

  login_as(@me, :scope => :user)
end

def bring_up_my_fab
  log_me_in FactoryGirl.create(:user_with_yesterweeks_fab)
  # Capybara.current_session.driver.header 'Referer', root_path
  visit user_fabs_path(@me)
end

def bring_up_anothers_fab_edit
  log_me_in

  @other = FactoryGirl.create(:user_with_yesterweeks_fab, email: 'other@example.com')

  # Capybara.current_session.driver.header 'Referer', root_path
  visit user_fabs_path(@other)
end

# The markup contains a &zwnj; which is confusing and annoying as hell
def strip_unprintable_characters(s)
  s.tr(8204.chr, "")
end
