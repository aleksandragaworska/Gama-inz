/***
* Name: model
* Author: olaga
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model grywalizacja


global {
	float step <- 15 # mn;
	
	file shp_agents <- file ("../includes/mieszkancy.shp");
	file shp_objects <- file ("../includes/obiekty.shp");
	file shp_boundaries <- file ("../includes/miasto_region.shp");
	file shp_districts <- file ("../includes/dzielnice.shp");
	file shp_roads <- file("../includes/drogi.shp");
	
	geometry shape <- envelope(shp_boundaries);	
	
	float changeEngagementsTheMost <- 0.15 / (cycle + 1); 
	float changeEngagementsMax <- 0.1 / (cycle + 1); 
	float changeEngagementsAvg <- 0.05 / (cycle + 1); 
	float changeEngagementsMin <- 0.01 / (cycle + 1); 
	
	float changeIfSocialMeetKiller <- 0.001 / (cycle + 1);
	float changeIfIamKiller <- 0.0005 / (cycle + 1);
	float changeIfNormalMeetKiller <- 0.0001 / (cycle + 1);
	
	
	float workers <- 0.75;
	float workers_in_office <- 0.5;
	float blockers <- 0.8;
	float players <- 0.45;
	
	float maxDistance <- 0.25 #km;
	float maxDistanceBeetwenPeople <- 20 #m;
	graph theGraph;

	int days update: time / #days;
	int currentDay update: (time / #days) mod 7;
	float currentHour update: (time / #hours) - 24.0 * days;
	
	int minWorkStart <- 7;
	int maxWorkStart <- 10;
	int minWorkEnd <- 15;
	int maxWorkEnd <- 18;
	int minFreeTimeStart <- 16;
	int maxFreeTimeStart <- 19;
	int minFreeTimeStartIfNotWorker <- 9;
	int maxFreeTimeStartIfNotWorker <- 12;
	int minFreeTimeEndIfNotWorker <- 16;
	int minFreeTimeEnd <- 21;
	int maxFreeTimeEnd <- 23;
	int minFreeTimeStartWeekend <- 10;
	int maxFreeTimeStartWeekend <- 14;
	float maxSpeed <- 30 #km/#h;
	float minSpeed <- 5 #km/#h;
	
	

	init {
		/* tworzenie agentów */
		create road from: shp_roads;
		theGraph <- as_edge_graph(road);
		
		create district from: shp_districts with: [name::string(read("NAZWA"))] {
			distColor <- rgb(153, 255, 102); 
		}
		
		create object from: shp_objects with: [type::string(read("TYP")), needs::bool(read("POTRZEBA")), prize_num::float(read("NAGRODA"))
		]{
			
			if (type = "niska zabudowa") {
				objColor <- rgb(160, 160, 169); 
			}
			else if (type = "blokowisko") {
				objColor <- rgb(128, 128, 128); 
			}
			else if (type = "biurowiec") {
				objColor <- rgb(218, 112, 214);
			}
			else if (type = "bulwary") {
				objColor <- rgb(255, 215, 0); 
			}
			else if (type = "park") {
				objColor <- rgb(50, 255, 50); 
			}
			else if (type = "fabryka") {
				objColor <- rgb(100, 100, 100); 
			}
			else if (type = "zabytek") {
				objColor <- rgb(210, 105, 30); 
			}
			else if (type = "rzeka") {
				objColor <- rgb(50, 50, 255); 
			}
			else if (type = "przychodnia" or type = "szkola" or type = "urzad") {
				objColor <- rgb(85, 107, 47); 
			}
			
			height <- 20 + rnd(200);
			
			if (prize_num < 0.25) {
				prize <- "bilety_komunikacyjne";
			} else if (prize_num < 0.5) {
				prize <- "bilety_do_kina";
			} else if (prize_num < 0.75) {
				prize <- "kolejka_lekarz";
			} else if (prize_num >= 0.75){
				prize <- "szybciej_przedszkole";
			}
			
		}
		
		list<object> detached_houses <- object where (each.type = "niska zabudowa");
		list<object> blocks <- object where (each.type = "blokowisko");
		list<object> homes <- object where (each.type = "niska zabudowa" or each.type = "blokowisko");
		list<object> offices <- object where (each.type = "biurowiec");
		list<object> factories <- object where (each.type = "fabryka");
		list<object> surgeries <- object where (each.type = "przychodnia");
		list<object> cultural_centers <- object where (each.type = "park" or each.type = "bulwary" or each.type = "zabytek");
		list<object> departments <- object where (each.type = "urzad");
		list<object> schools <- object where (each.type = "szkola");

		create person from: shp_agents with: [id::int(read("ID")), age::float(read("AGE")), altruism::float(read("ALTRUISM")), 
			health::float(read("HEALTH")), identity::float(read("IDENTITY")), numOfChildren::int(read("CHILDREN")), 
			engagement::float(read("ENGAGEMENT")), hasCar::bool(read("HAS_CAR")), sporty::float(read("SPORTY")), cultural::float(read("CULTURAL")), 
			isKiller::bool(read('KILLER')), isSocialworker::bool(read('SOCIALWORK')) 
		]{
			startEngagement <- engagement;
			objective <- "at_home";
			temp_objective <- false;
			
			
			mySpeed <- minSpeed + rnd(maxSpeed - minSpeed) #km/#h;
			
			living <- flip(blockers) ? one_of(blocks) : one_of(detached_houses);
			
			is_worker <- flip(workers) ? true : false;		
			if (is_worker) {
				startWork <- minWorkStart + rnd((maxWorkStart - minWorkStart) * 60) / 60;
				endWork <- minWorkEnd + rnd((maxWorkEnd - minWorkEnd) * 60) / 60;
				working <- flip(workers_in_office) ? one_of(offices) : one_of(factories);
			}
			
			
			myDistrict <- district closest_to(living);
			
			is_player <- flip(players) ? true : false;
			if (is_player) {
				if (is_worker = false) {
					startFreeTime <- minFreeTimeStartIfNotWorker + rnd((maxFreeTimeStartIfNotWorker - minFreeTimeStartIfNotWorker) * 60) / 60;
					endFreeTime <- minFreeTimeEndIfNotWorker + rnd((maxFreeTimeEnd - minFreeTimeEndIfNotWorker) * 60) / 60;
				}
				else {
					if (endWork <= minFreeTimeStart) {
						startFreeTime <- minFreeTimeStart + rnd((maxFreeTimeStart - minFreeTimeStart) * 60) / 60;
					}
					else {
						startFreeTime <- endWork + rnd((maxFreeTimeStart - endWork) * 60) / 60;
					}
					endFreeTime <- minFreeTimeEnd + rnd((maxFreeTimeEnd - minFreeTimeEnd) * 60) / 60;
				}
				startFreeTimeWeekend <- minFreeTimeStartWeekend + rnd((maxFreeTimeStartWeekend - minFreeTimeStartWeekend) *60) / 60;
				endFreeTimeWeekend <- minFreeTimeEnd + rnd((maxFreeTimeEnd - minFreeTimeEnd) * 60) / 60;				
				playing <- cultural_centers;
			}
			
			myDay <- -1;
		}
	}
}

species road {
	aspect base {
		draw shape color: #blue;
	}
}

species district {
	rgb distColor;
	aspect base {
		draw shape color: distColor;
	}
}

species object {
	string type;
	bool needs;
	float prize_num;
	string prize;
	int height;
	rgb objColor;
	aspect base {
		draw shape color: objColor;
	}
}

species person skills: [moving] {
	int id;
	float age;
	float altruism;
	float health;
	float identity;
	int numOfChildren;
	bool isKiller;
	bool isSocialworker;
	float engagement min:0.0 max:1.0;
	bool hasCar;
	float sporty;
	float cultural;
	bool is_worker;
	bool is_player;
	float startEngagement;
	
	
	string objective;
	float startWork;
	float endWork;
	float startFreeTime;
	float endFreeTime;
	float startFreeTimeWeekend;
	float endFreeTimeWeekend;
	float mySpeed;
	point myTarget;
	
	bool temp_objective;
	int myDay;
	
	object living;
	object working;
	district myDistrict;
	list<object> playing;
	
	aspect base {
		draw circle(10) color: #red;
	}
	
	
	list<object> objectInNeighbour update: object at_distance maxDistance;

	object currentPlace update: object closest_to(location);
	
	list<person> myFriendsKillers <- person where (each.isKiller) update: (person at_distance maxDistanceBeetwenPeople where each.isKiller);
	
	reflex home_work when: working != nil and objective = "at_home" 
	and (currentHour > startWork - 0.25 and currentHour < startWork + 0.25) and currentDay < 5 {
		objective <- "at_work";
		temp_objective <- false;
		myTarget <- any_location_in(working); 
	}
	
	reflex work_home when: living != nil and objective = "at_work" 
	and (currentHour > endWork - 0.25 and currentHour < endWork + 0.25) {
		objective <- "at_home";
		temp_objective <- false;
		myTarget <- any_location_in(living);
	}
	
	reflex home_play when: is_player = true and objective = "at_home" 
	and (((currentHour > startFreeTime - 0.25 and currentHour < startFreeTime + 0.25) and currentDay < 5) 
		or (currentDay > 4 and (currentHour > startFreeTimeWeekend - 0.25 and currentHour < startFreeTimeWeekend + 0.25))) {
		objective <- "in_town";
		temp_objective <- false;
		myTarget <- any_location_in(one_of(playing));
	}
	
	reflex play_home when: living != nil and objective = "in_town" 
	and (((currentHour > endFreeTime - 0.25 and currentHour < endFreeTime + 0.25) and currentDay < 5) 
		or (currentDay > 4 and (currentHour > endFreeTimeWeekend - 0.25 and currentHour < endFreeTimeWeekend + 0.25))) {
		objective <- "at_home";
		temp_objective <- false;
		myTarget <- any_location_in(living);
	}
	

	
	reflex move when: myTarget != nil {
		path myPath <- self goto [target::myTarget, speed::mySpeed, on::theGraph, return_path::true];
	}

	
	reflex update {		
		if (currentHour >= 7 and currentHour <= 21) {
				ask one_of(objectInNeighbour) {
					if (self.needs = true) {
							if (myself.temp_objective = false and myself.myDay != currentDay) {						
								if (type = "szkola") {
									if (myself.numOfChildren > 0) {
										if (prize = "szybciej_przedszkole") {
											myself.engagement <- myself.engagement + changeEngagementsTheMost * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										} else if (prize_num > 0.1) {
											myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										}
									}
								} else if (type = "zabytek") {
									if (myself.cultural > 0.9) {
										if (prize = "bilety_do_kina") {
											myself.engagement <- myself.engagement + changeEngagementsTheMost * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										} else if (prize_num > 0) {
											myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										}
									}
								} else if (type = "bulwary") {
									if (myself.sporty > 0.9 or myself.age > 0.6 or myself.age < 0.25 or myself.numOfChildren > 0) {
										myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
										myself.temp_objective <- true;
										myself.myDay <- currentDay;
									}
								}
								else if (myself.health < 0.3) {
									if (prize = "szybciej_lekarz") {
										if (myself.age > 0.6) {
											myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										} else {
											myself.engagement <- myself.engagement + changeEngagementsAvg * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										}
									}
								}
								else if (myself.age < 0.3) {
									if (prize = "bilety_komunikacyjne") {
										if (!myself.hasCar) {
											myself.engagement <- myself.engagement + changeEngagementsTheMost * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										} else {
											myself.engagement <- myself.engagement + changeEngagementsAvg * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										}
									}
								}
								else if (myself.altruism > 0.6) {
									if (myself.altruism > 0.9) {
										if (myself.currentPlace overlaps myself.myDistrict) { 
											if (myself.identity > 0.9) {
												myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
												myself.temp_objective <- true;
												myself.myDay <- currentDay;
											} else {
												myself.engagement <- myself.engagement + changeEngagementsAvg * myself.startEngagement;
												myself.temp_objective <- true;
												myself.myDay <- currentDay;
											}
										}
										else {
											myself.engagement <- myself.engagement + changeEngagementsAvg * myself.startEngagement;
											myself.temp_objective <- true;
											myself.myDay <- currentDay;
										}
									} 
									else {
										myself.engagement <- myself.engagement + changeEngagementsMin * myself.startEngagement;
										myself.temp_objective <- true;
										myself.myDay <- currentDay;
									}
								}
							}
						}
					}
				}
			}

	
	reflex changeEngagementWithKiller {
		if (length(myFriendsKillers) > 0 and temp_objective = true) {		
				person killer <- one_of(myFriendsKillers);
				ask(killer) { 
					if (myself.isSocialworker) { 
						myself.engagement <- myself.engagement - changeIfSocialMeetKiller * myself.startEngagement;							
						if (self.engagement <= myself.engagement) { 
							self.engagement <- self.engagement + changeIfIamKiller * self.startEngagement; 
						} 						
						else if (self.engagement > myself.engagement) { //
							self.engagement <- self.engagement - (changeIfIamKiller / 2) * self.startEngagement;
						}
					}
					else if (myself.isKiller) {
						myself.engagement <- myself.engagement + 2 * changeIfIamKiller * myself.startEngagement;
						self.engagement <- self.engagement + changeIfIamKiller * self.startEngagement;
					}
					else {
						myself.engagement <- myself.engagement + changeIfNormalMeetKiller * myself.startEngagement;
						if (self.engagement <= myself.engagement) { 
							self.engagement <- self.engagement + changeIfIamKiller * self.startEngagement; 
						} 
						else if (self.engagement > myself.engagement) { //
							self.engagement <- self.engagement - (changeIfIamKiller / 2) * self.startEngagement;
						}
					}
				}
			}
		}


	
	reflex save_person when: cycle = 0 or cycle = 96 or cycle = 672 or cycle = 1344 or cycle = 2688 {
		string fileName <- "output/Gamification_cycle" + cycle + ".csv";			
		save species_of(self) to: fileName type: csv;
	}
}

experiment first_experiment type: gui until: (cycle = 2688) {
	output {
		display map type: opengl {
			species district aspect: base;
			species object aspect: base;
			species person aspect: base;
			species road aspect: base;
		}
		
		display chart_display refresh:every(1 #cycle) {
          chart "People Objective" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
	       data "Work" value: person count (each.objective="at_work") color: #magenta ;
	       data "Home" value: person count (each.objective="at_home") color: #blue ;
	       data "Town" value: person count (each.objective="in_town") color: #green ;
	       }
	  }

				
	}
}
