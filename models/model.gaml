/***
* Name: model
* Author: olaga
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model grywalizacja

/* Insert your model definition here */

global {
	float step <- 60 # mn;
	
	file shp_agents <- file ("../includes/MIESZKANCY_MM_point.shp");
	file shp_objects <- file ("../includes/OBIEKTY_region.shp");
	file shp_boundaries <- file ("../includes/miasto_region.shp");
	file shp_districts <- file ("../includes/heksy_region.shp");
	file shp_roads <- file("../includes/drogi_polyline.shp");
	
	geometry shape <- envelope(shp_boundaries);	
	
	float changeEngagementsMaxMax <- 0.15 / (cycle + 1); // gdy wszystkie warunki pchają do zaangażowania (nagroda, potrzeba, okolica itd)
	float changeEngagementsMax <- 0.1 / (cycle + 1); // gdy prawie wszystkie warunki pchają do zaangażowania
	float changeEngagementsAvg <- 0.05 / (cycle + 1); // gdy 2 z 3 w/w warunków występują
	float changeEngagementsMin <- 0.01 / (cycle + 1); // gdy występuje tylko 1 z w/w warunków
	
	float changeIfKiller <- 0.001 / (cycle + 1);
	
	float workers <- 0.75;
	float workers_in_office <- 0.5;
	float blockers <- 0.8;
	float players <- 0.45;
	
	float maxDistance <- 1.0 #km;
	graph theGraph;
//	
//	int currentHour update: (time / #hour) mod 24;
//	int currentDay update: (time / #days) mod 7;

	int days update: time / #days;
	int currentDay update: (time / #days) mod 7;
	float currentHour update: (time / #hours) - 24.0 * days;
	
	int minWorkStart <- 7;
	int maxWorkStart <- 10;
	int minWorkEnd <- 15;
	int maxWorkEnd <- 18;
	int minFreeTimeStart <- 16;
	int maxFreeTimeStart <- 19;
	int minFreeTimeEnd <- 21;
	int maxFreeTimeEnd <- 23;
	float maxSpeed <- 30 #km/#h;
	float minSpeed <- 5 #km/#h;
	
	

	init {
		create road from: shp_roads;
		theGraph <- as_edge_graph(road);
		
		create district from: shp_districts with: [name::string(read("NAZWA"))] {
			distColor <- rgb(255, 102, 102); //malinowy
		}
		
		create object from: shp_objects with: [type::string(read("TYP")), needs::bool(read("POTRZEBA")), prize_num::float(read("NAGRODA"))
		]{
//			list<object> withNeeds <-  (type, prize) where needs;
			
			if (type = "niska zabudowa") {
				objColor <- rgb(0, 51, 102); //ciemnoniebieski
			}
			else if (type = "blokowisko") {
				objColor <- rgb(128, 128, 128); //szary
			}
			else if (type = "biurowiec") {
				objColor <- rgb(153, 51, 255);//fioletowy
			}
			else if (type = "bulwary") {
				objColor <- rgb(153, 255, 153); //błękitny
			}
			else if (type = "park") {
				objColor <- rgb(0, 255, 0); //zielony
			}
			else if (type = "fabryka") {
				objColor <- rgb(0, 0, 0); //czarny
			}
			else if (type = "zabytek") {
				objColor <- rgb(255, 0, 0); //czerwony
			}
			else if (type = "rzeka") {
				objColor <- rgb(0, 0, 255); //niebieski
			}
			else if (type = "przychodnia" or type = "szkola" or type = "urzad") {
				objColor <- rgb(51, 102, 0); //ciemnozielony
			}
			
			height <- 20 + rnd(200);
			
			if (prize_num > 0.1 and prize_num < 0.25) {
				prize <- "bilety_komunikacyjne";
			} else if (prize_num < 0.5) {
				prize <- "bilety_do_kina";
			} else if (prize_num < 0.75) {
				prize <- "kolejka_lekarz";
			} else if (prize_num >= 0.75){
				prize <- "szybciej_przedszkole";
			}
			
		}
		
		list<object> flats <- object where (each.type = "niska zabudowa");
		list<object> blocks <- object where (each.type = "blokowisko");
		list<object> homes <- object where (each.type = "niska zabudowa" or each.type = "blokowisko");
		list<object> offices <- object where (each.type = "biurowiec");
		list<object> factories <- object where (each.type = "fabryka");
		list<object> surgeries <- object where (each.type = "przychodnia");
		list<object> cultural_centers <- object where (each.type = "park" or each.type = "bulwary" or each.type = "zabytek");
		list<object> departments <- object where (each.type = "urzad");
		list<object> schools <- object where (each.type = "szkola");

		/* tworzenie agentów */
		create person from: shp_agents with: [id::int(read("ID")), age::float(read("AGE")), altruism::float(read("ALTRUISM")), 
			education::float(read("EDUCATION")), happiness::float(read("HAPPINESS")), wealth::float(read("WEALTH")), identity::float(read("IDENTITY")),
			isMarried::bool(read("MARRIED")), numOfChildren::int(read("CHILDREN")), engagement::float(read("ENGAGEMENT")), hasCar::bool(read("HAS_CAR")),
			sporty::float(read("SPORTY")), cultural::float(read("CULTURAL")), isKiller::bool(read('KILLER')), 
			isSocialworker::bool(read('SOCIALWORK')) //married bool or int?
		]{
			startEngagement <- engagement;
			objective <- "at_home";
			temp_objective <- false;
			
			startWork <- minWorkStart + rnd((maxWorkStart - minWorkStart) * 60) / 60;
			endWork <- minWorkEnd + rnd((maxWorkEnd - minWorkEnd) * 60) / 60;
			startFreeTime <- minFreeTimeStart + rnd((maxFreeTimeStart - minFreeTimeStart) * 60) / 60;
			endFreeTime <- minFreeTimeEnd + rnd((maxFreeTimeEnd - minFreeTimeEnd) * 60) / 60;
			
			speed <- minSpeed + rnd(maxSpeed - minSpeed) #km/#h;
			
			living <- flip(blockers) ? one_of(blocks) : one_of(flats);
			working <- flip(workers_in_office) ? one_of(offices) : one_of(factories);
			myDistrict <- district closest_to(living);
			playing <- one_of(cultural_centers);
			
			engagementTime <- 0;
		}
	}
}

species road {
	aspect base {
		draw shape color: #blue;
	}
}

species district {
//	string name;
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
//	list withNeeds;
	aspect base {
		draw shape color: objColor;
	}
}

species person skills: [moving] {
	int id;
	float age;
	float altruism;
	float education;
	float happiness;
	float wealth;
	float identity;
	bool isMarried;
	int numOfChildren;
	bool isKiller;
	bool isSocialworker;
	float engagement;
//	float engagement min:0.0 max:1.0;
	bool hasCar;
	float sporty;
	float cultural;
	float startEngagement;
	
	
	string objective;
	float startWork;
	float endWork;
	float startFreeTime;
	float endFreeTime;
	float speed;
	point myTarget;
	
	bool temp_objective;
	
	object living;
	object working;
	district myDistrict;
	object playing;
	int engagementTime;
	
	aspect base {
		draw circle(10) color: #yellow;
	}
	
	list<object> objectInNeighbour update: object at_distance maxDistance;

	object currentPlace update: object closest_to(location);
	
	reflex home_work when: working != nil and objective = "at_home" 
	and (currentHour > startWork - 1.0 and currentHour < startWork + 1.0) and currentDay < 5 
	and age > 0.20 and flip(workers) {
		objective <- "at_work";
		myTarget <- any_location_in(working);
	}
	
	reflex work_home when: living != nil and objective = "at_work" 
	and (currentHour > endWork - 1.0 and currentHour < endWork + 1.0) {
		objective <- "at_home";
		myTarget <- any_location_in(living);
	}
	
	reflex home_play when: playing != nil and objective = "at_home" 
	and (((currentHour > startFreeTime - 1.0 and currentHour < startFreeTime + 1.0) and currentDay < 5) 
		or (currentDay > 4 and currentHour > 10)) and flip(players) {
		objective <- "in_town";
		myTarget <- any_location_in(playing);
	}
	
	reflex play_home when: living != nil and objective = "in_town" 
	and (currentHour > endFreeTime - 1.0 and currentHour < endFreeTime + 1.0) {
		objective <- "at_home";
		myTarget <- any_location_in(living);
	}
	

	
	reflex move when: myTarget != nil {
		path myPath <- self goto [target::myTarget, on::theGraph, return_path::true];
		list<geometry> segments <- myPath.segments;
		loop line over: segments
		{
			float dist <- line.perimeter;
		}

		if myTarget = location
		{
			myTarget <- nil;
			location <- { location.x, location.y, currentPlace.height };
		}
	}
	
//	reflex writeCurrentEngagement {
//		write(self.name + "has current engagement: " + self.engagement);
//	}
//	action modifyEngagement() 
	
	reflex update {
		if (currentHour > 7 and currentHour < 21) {
			ask person {
	//			write 'Test ' + self.name;
				ask one_of(objectInNeighbour) {
	//				write 'Test ' + type;
	//				if (self.needs = 1) {
	//					write self.needs;
	//					if (self overlaps myself and myself.temp_objective = true) {
	//						write "Person: "+myself.name+" cycle: "+cycle+" temp: "+myself.temp_objective;
	//					}
	//					else if (self overlaps myself and myself.temp_objective != myself.objective) {
						if (self overlaps myself and myself.temp_objective = false) {
	//						write myself.temp_objective;
	//						if (type = 'blokowisko') {
	//							write 'Blok';
	//						}							
							if (type = "szkola") { //or one_of(schools) <- to nie działa
	//							write 'AAA';
								if (myself.numOfChildren > 0) {
									if (prize = "szybciej_przedszkole") {
										myself.engagement <- myself.engagement + changeEngagementsMaxMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "przedszkole: " + myself.engagement;
									} else if (prize_num > 0.1) {
										myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "przedszkole2: " + myself.engagement;
									}
								}
							} else if (type = "zabytek") {
	//							write 'BBB';
								if (myself.cultural > 0.7) {
									if (prize = "bilety_do_kina") {
										myself.engagement <- myself.engagement + changeEngagementsMaxMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "kino: " + myself.engagement;
									} else if (prize_num > 0) {
										myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "kino2: " + myself.engagement;
									}
								}
							} else if (type = "bulwary") {
	//							write 'CCC';
								if (myself.sporty > 0.7 or myself.age > 0.6 or myself.numOfChildren > 0) {
									myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
	//								write "Person: "+myself.name+" eng: "+myself.engagement;
									myself.temp_objective <- true;
	//								write "bulwary: " + myself.engagement;
								}
							}
							else if (myself.wealth < 0.3) {
								if (prize = "szybciej_lekarz") {
									if (myself.age > 0.6) {
										myself.engagement <- myself.engagement + changeEngagementsMaxMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "lekarz: " + myself.engagement;
									} else {
										myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "lekarz2: " + myself.engagement;
									}
								}
							}
							else if (myself.age > 0.2 and myself.age < 0.35) {
								if (prize = "bilety_komunikacyjne") {
									if (!myself.hasCar) {
										myself.engagement <- myself.engagement + changeEngagementsMaxMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "komunikacja: " + myself.engagement;
									} else {
										myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "komunikacja2: " + myself.engagement;
									}
								}
							}
							else if (myself.altruism > 0.7) {
								if (myself.currentPlace = myself.myDistrict) { 
									if (myself.identity > 0.7) {
										myself.engagement <- myself.engagement + changeEngagementsMax * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "identyfikacja+altruism: " + myself.engagement;
									} else {
										myself.engagement <- myself.engagement + changeEngagementsAvg * myself.startEngagement;
										myself.temp_objective <- true;
	//									write "moja dzielnia+altruism: " + myself.engagement;
									}
								} else if (myself.altruism > 0.4){
									myself.engagement <- myself.engagement + changeEngagementsMin * myself.startEngagement;
									myself.temp_objective <- true;
	//								write "altruism: " + myself.engagement;
								}
							}
						}
	//				}
					}
				}
			}
		}
//		if (engagement = 1 ) {
//			write name + ' cycle: ' + cycle + ' enga: ' + engagement; 
//		}
//	list<person> killer update: person where isKiller;
//	list<person> socialWorker update: person where isSocialworker;
	
	reflex changeEngagementWithKiller {
		if (currentHour > 7 and currentHour < 21) {
			list<person> killers <- person at_distance(maxDistance) where (each.isKiller);
	//		list<person> socialWorker <- person at_distance(maxDistance) where isSocialworker;
			person killer <- one_of(killers);
			ask(person) { // myself
				ask(killer) { // self
	//				if (one_of(killer) != nil) {
	//					write myself.name + ' '+ myself.isKiller;
		//				if (one_of(myself neighbors_at(maxDistance)) = self) {
		//					write myself.isKiller;
		//					write self.isSocialworker;
		//					write cycle;
	//					write 'killer: '+one_of(killer)+' me: '+self.name;
						if (myself.isSocialworker and myself.temp_objective = false) { 
							myself.engagement <- myself.engagement - changeIfKiller * myself.startEngagement;	
							//for full simulations: 5000, for part(100 cycles): 500, for the shortest(10 cycle): 50
							if (self.engagementTime < 50) { 
								//at the beginning, killer want to kill every social workers
								self.engagement <- self.engagement + changeIfKiller * self.startEngagement; 
							} 
							//for full simulations: 15000, for part(100 cycles): 1500, for the shortest(10 cycle): 150
							else if (self.engagementTime > 150) { //
								//later, when he won, his interest to win falls
								self.engagement <- self.engagement - changeIfKiller * self.startEngagement;
							}
	//						write 'person' + myself.name + ' param: ' + myself.engagementTime + ' cycle: ' + cycle;
							//times when "met" social worker
							self.engagementTime <- self.engagementTime + 1;
						}
						else if (myself.isKiller and myself.temp_objective = false) {
							myself.engagement <- myself.engagement + changeIfKiller * myself.startEngagement;
							self.engagement <- self.engagement + 2 * changeIfKiller * self.startEngagement;
						}
	//				}
				}
			}
		}
	}

//	reflex write_text {
//		write 'cycle: ' + cycle + ' currentHour: ' + currentHour + ' currentDay: ' + currentDay;
//	}
	
	reflex save_person when: cycle = 10 or cycle = 50 or cycle = 100 or cycle = 400 or cycle = 1000 {
//		string fileName <- "output/firstCSV_cycle" + cycle + ".csv";
//		string fileName2 <- "output/allAgents_cycle" + cycle + ".csv";
//		string fileName3 <- "output/objective_cycle" + cycle + ".csv";
//		string fileName4 <- "output/speciesOf2_cycle" + cycle + ".csv";
		string fileName5 <- "output/withKillerWithoutMinMaxAndAddTime2_cycle" + cycle + ".csv";
		
//		save [self, self.age, self.numOfChildren, self.wealth, self.cultural, 
//			self.sporty, self.altruism, self.identity, self.myDistrict, 
//			self.startEngagement, self.engagement
//		] to: fileName type: csv;
		
//		save species_of(self) to: fileName4 type: csv;
		
		save species_of(self) to: fileName5 type: csv;
//		
//		save [agents] to: fileName2 type: csv;
//		save [self.name, self.objective, ]
	}

}

experiment first_experiment type: gui until: (cycle = 3600) {
//	reflex write_text {
//		write "Person " + person.id + " has engagement "+ person.engagement;
//	}
	output {
		display map type: opengl {
			species district aspect: base;
			species object aspect: base;
			species person aspect: base;
			species road aspect: base;
		}
		
		display chart_display refresh:every(1 #cycle) {
          chart "People Objectif" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
	       data "Work" value: person count (each.objective="at_work") color: #magenta ;
	       data "Home" value: person count (each.objective="at_home") color: #blue ;
	       data "Town" value: person count (each.objective="in_town") color: #green ;
	       }
	  }

				
	}
}
