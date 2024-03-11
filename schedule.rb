require 'set'
require 'byebug'
#
# 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36
# 1,2,3    vs 4,5,6
# 7,8,9    vs 10,11,12
# 13,14,15 vs 16,17,18
# 19,20,21 vs 22,23,24
# 25,26,27 vs 28,29,30
# 31,32,33 vs 34,35,36
#
# 1,4,5   vs 
#

class Scheduler
  def initialize(num_teams=36, num_matches=11)
    @teams = (1..num_teams).to_a
    @matches = (1..num_matches).to_a

    @teammates_by_team = {}
    @opponents_by_team = {}
    @teams.each do |team|
      @teammates_by_team[team] = {}
      @opponents_by_team[team] = {}
      @teams.each do |other_team|
        next if team == other_team

        @teammates_by_team[team][other_team] = 0
        @opponents_by_team[team][other_team] = 0
      end
    end

    @curr_round_matches = []
    @curr_match = { red: [], blue: [] }
    
  end

  def can_work(team, curr_round_teammates, curr_round_opponents)
    curr_round_teammates.each do |ct|
      return false if @teammates_by_team[ct][team] >= 1
    end

    curr_round_opponents.each do |co|
      return false if @opponents_by_team[co][team] >= 1
    end
    
    true
  end


  def schedule_round(round_num)
    curr_teammates_by_team = @teammates_by_team.dup
    curr_opponents_by_team = @opponents_by_team.dup

    curr_round_matches = []
    curr_match = { red: [], blue: [] }
    
    teams = @teams.dup
    if round_num >= 2
      teams.shuffle!
    end
    40.times do 
      # don't use the teams array, cuz we're deleting from it
      (1..@teams.length).each do |team|
        puts "trying place #{team}" 
        if curr_match[:red].length < 3 && can_work(team, curr_match[:red], curr_match[:blue])
          curr_match[:red].each do |existing_red_team|
            curr_teammates_by_team[existing_red_team][team] += 1
            curr_teammates_by_team[team][existing_red_team] += 1
          end
          curr_match[:blue].each do |existing_blue_team|
            curr_opponents_by_team[existing_blue_team][team] += 1
            curr_opponents_by_team[team][existing_blue_team] += 1
          end
          curr_match[:red] << team
          teams.delete(team)
        elsif curr_match[:blue].length < 3 && can_work(team, curr_match[:blue], curr_match[:red])
          curr_match[:blue].each do |existing_blue_team|
            curr_teammates_by_team[existing_blue_team][team] += 1
            curr_teammates_by_team[team][existing_blue_team] += 1
          end
          curr_match[:red].each do |existing_red_team|
            curr_opponents_by_team[existing_red_team][team] += 1 
            curr_opponents_by_team[team][existing_red_team] += 1
          end
          curr_match[:blue] << team
          teams.delete(team)
        end

        if curr_match[:red].length == 3 && curr_match[:blue].length == 3
          curr_round_matches << curr_match
          puts "Finished match #{curr_match}"

          # reset it
          curr_match = { red: [], blue: [] }
        end

      end
    end

    if teams.count > 0
      puts "Failed to schedule round #{round_num}"
      byebug
    end
  end

  def schedule_event
    10.times do |idx|
      schedule_round(idx)
      puts "----------"
    end

    a=1
  end
end

scheduler = Scheduler.new(76, 10)
#scheduler = Scheduler.new(36, 11)
scheduler.schedule_event
