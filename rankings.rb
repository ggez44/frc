require 'date'
require 'fileutils'
require 'uri'
require 'net/http'
require 'json'

require 'byebug'

API_KEY = "bUdXNYQIL7C5HYLSX966jAqfpmjbzocnaCoTdABBsOaHFAuyyid781XDRxwOrZD4"

def query(path, params = {})
  3.times do |i|
    uri = URI.parse("https://www.thebluealliance.com/api/v3/#{path}")
    uri.query = URI.encode_www_form(params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl=true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    headers = {"X-TBA-Auth-Key" => API_KEY}
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    return JSON.parse(response.body) if response.code == "200"
  rescue
  end
end


def run_event(event_key, stat)
  if !event_key
      raise "No event key"
  end

  cacheable_event = true
  #puts("checking #{event_key}")

  cache_file_name = "cache/event_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    matches = File.open(cache_file_name) { |f| JSON.load(f) }
  else
    event = query("event/#{event_key}")
    event_end_date = Date.parse(event["end_date"])
    days_diff = (Date.today - event_end_date).to_i
    if days_diff < 2
      cacheable_event = false
    end
      
    matches = query("event/#{event_key}/matches")
    if cacheable_event
      # only cache done events
      File.open(cache_file_name, "w") do |file|
        JSON.dump(matches, file)
      end
    end
  end

  team_scores = {}

  cache_file_name = "cache/event_cache_#{event_key}_#{stat}.json"
  if File.exists?(cache_file_name)
    return File.open(cache_file_name) { |f| JSON.load(f) }
  else
    print(".")
    if stat == "climb"
      team_scores = run_climb(matches)
    else
      50.times do
        team_scores = run_iteration(stat, team_scores, matches)
        #pprint(team_scores)
      end
    end

    if cacheable_event
      File.open(cache_file_name, "w") do |file|
        JSON.dump(team_scores, file)
      end
    end
  end

  return team_scores
end

def run_climb(matches)
  team_info = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_info[team] = {"total"=> 0, "count"=> 0} if !team_info.key?(team)
    end

    team_info[team1]["total"] += 1 if !["Parked", "None"].include?(match["score_breakdown"]["blue"]["endGameRobot1"])
    team_info[team2]["total"] += 1 if !["Parked", "None"].include?(match["score_breakdown"]["blue"]["endGameRobot2"])
    team_info[team3]["total"] += 1 if !["Parked", "None"].include?(match["score_breakdown"]["blue"]["endGameRobot3"])
    team_info[team4]["total"] += 1 if !["Parked", "None"].include?(match["score_breakdown"]["red"]["endGameRobot1"])
    team_info[team5]["total"] += 1 if !["Parked", "None"].include?(match["score_breakdown"]["red"]["endGameRobot2"])
    team_info[team6]["total"] += 1 if !["Parked", "None"].include?(match["score_breakdown"]["red"]["endGameRobot3"])

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_info[team]["count"] += 1
    end

  end

  team_scores = {}
  team_info.each do |team_num, team_data|
    team_scores[team_num] = {"score" => team_data["total"].to_f / team_data["count"]}
  end

  return team_scores
end


def run_iteration(stat, team_scores, matches)
  iteration_team_scores = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }
      
    case stat
    when "eps"
      blue_score = match["score_breakdown"]["blue"]["totalPoints"]
      red_score = match["score_breakdown"]["red"]["totalPoints"]
    when "epps" 
      # look at opponent alliance foulPoints - TBA looks at own alliance which is meaningless
      blue_score = match["score_breakdown"]["red"]["foulPoints"]
      red_score = match["score_breakdown"]["blue"]["foulPoints"]
    end

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_scores[team] ||= { "score" => 0 }
      iteration_team_scores[team] ||= { "score" => 0, "matches" => 0 }
    end

    alliance1_total = [team_scores[team1]["score"], team_scores[team2]["score"], team_scores[team3]["score"]].sum
    if alliance1_total == 0
      alliance1_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance1_percentages = [team_scores[team1]["score"], team_scores[team2]["score"], team_scores[team3]["score"]].map { |score| score.to_f / alliance1_total }
    end

    alliance2_total = [team_scores[team4]["score"], team_scores[team5]["score"], team_scores[team6]["score"]].sum
    if alliance2_total == 0
      alliance2_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance2_percentages = [team_scores[team4]["score"], team_scores[team5]["score"], team_scores[team6]["score"]].map { |score| score.to_f / alliance2_total }
    end

    iteration_team_scores[team1]["score"] += alliance1_percentages[0] * blue_score.to_i
    iteration_team_scores[team2]["score"] += alliance1_percentages[1] * blue_score.to_i
    iteration_team_scores[team3]["score"] += alliance1_percentages[2] * blue_score.to_i

    iteration_team_scores[team4]["score"] += alliance2_percentages[0] * red_score.to_i
    iteration_team_scores[team5]["score"] += alliance2_percentages[1] * red_score.to_i
    iteration_team_scores[team6]["score"] += alliance2_percentages[2] * red_score.to_i

    if [team1, team2, team3, team4, team5, team6].include?("6238")
      #byebug
    end

    [team1, team2, team3, team4, team5, team6].each do |team|
      iteration_team_scores[team]["matches"] += 1
    end

  end

  iteration_team_scores.map do |team, score|
    team_scores[team]["score"] = score["score"] / score["matches"]
  end

  team_scores
end

def pprint(team_scores)
  idx = 0

  puts "\n==================="
  if team_scores.length == 0
    puts "No data yet"
  end
  team_scores.sort_by { |team, score| score["score"] }.reverse.each do |team, score|
    puts "#{idx+=1}. #{team} - #{score["score"].round(2)}"
  end
end

def display_menu()
  puts "\n\n"
  puts "###################################################################\n#"
  if ARGV[1].nil?
    puts "#     Stats for #{ARGV[0]} teams using #{ARGV[0]} matches"
  else
    puts "#     Stats for #{ARGV[0]} teams using teams' latest event matches"
  end
  puts "#\n###################################################################"
  puts "\n"
  puts "1) Estimated Points Share (sans fouls)"
  puts "2) Estimated Penalty Points Share (more is bad)"
  puts "3) Successful Climb Percentage (exact)"
  puts ""
  puts "[c]lear cache"
  puts "[q]uit"
  puts ""
  print "Enter choice: "
end

def handle_choice(choice)
  # if there is a second command line arg of any kind.. we use prev event
  use_prev_event_data = !ARGV[1].nil?

  case choice
  when "1"
    if use_prev_event_data
      pprint(get_prev_teams_stats("eps"))
    else
      pprint(run_event(ARGV[0], "eps"))
    end
  when "2"
    if use_prev_event_data
      pprint(get_prev_teams_stats("epps"))
    else
      pprint(run_event(ARGV[0], "epps"))
    end
  when "3"
    if use_prev_event_data
      pprint(get_prev_teams_stats("climb"))
    else
      pprint(run_event(ARGV[0], "climb"))
    end
  when "c"
    FileUtils.rm_rf("cache")
  end
end

def run_menu()
  FileUtils.mkdir_p("cache")
  choice = ''
  until choice == 'q'
    display_menu()
    choice = STDIN.gets.chomp
    handle_choice(choice)
  end
end

def get_teams_last_event()
  cache_file_name = "cache/last_event_cache_#{ARGV[0]}.json"
  if File.exists?(cache_file_name)
    puts "Using cached last_event data"
    return File.open(cache_file_name) { |f| JSON.load(f) }
  end

  team_keys = get_team_keys()

  team_last_event_map = {}
  team_keys.each do |team_key|
    matches = query("team/#{team_key}/matches/2024")
    filtered_matches = matches.select { |match| match["actual_time"] }
    most_recent_match = filtered_matches.max_by { |match| match["actual_time"] }
    team_last_event_map[team_key] = most_recent_match["event_key"]
    #puts "#{team_key}: #{most_recent_match['event_key']}"
    print('.')
  end

  File.open(cache_file_name, "w") do |file|
    JSON.dump(team_last_event_map, file)
  end

  return team_last_event_map
end

def get_team_keys()
  teams = query("event/#{ARGV[0]}/teams")
  return teams.map{ |team| team["key"] }
end

def get_prev_teams_stats(stat)
  team_last_events = get_teams_last_event()

  team_results = {}

  team_last_events.each do |team_key, event_key|
    team_number = team_key.sub('frc', '')
    event_results = run_event(event_key, stat)
    team_results[team_number] = event_results[team_number]
  end

  return team_results
end

run_menu()

