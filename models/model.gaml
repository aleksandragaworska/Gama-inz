/***
* Name: model
* Author: olaga
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model grywalizacja

/* Insert your model definition here */

global {
	float step <- 1 # mn;
	
	file shp_agents <- file ("../includes/MIESZKANCY_MM_point.shp");
	file shp_objects <- file ("../includes/OBIEKTY_region.shp");
	file shp_boundaries <- file ("../includes/miasto_region.shp");
	file shp_districts <- file ("../includes/heksy_region.shp");
	file shp_roads <- file("../includes/drogi_polyline.shp");
	
	geometry shape <- envelope(shp_boundaries);	
	
	float changeEngagementsMax <- 0.5; // gdy wszystkie warunki pchają do zaangażowania (nagroda, potrzeba, okolica)
	float changeEngagementsAvg <- 0.3; // gdy 2 z 3 w/w warunków występują
	float changeEngagementsMin <- 0.1; // gdy występuje tylko 1 z w/w warunków
	
	float workers <- 0.5;
	float blockers <- 0.8;
	
	float maxDistance <- 3.0 #km;
	graph theGraph;
	
	int currentHour update: (time / #hour) mod 24;
	int currentDay update: (time / #days) mod 7;
	
	int minWorkStart <- 7;
	int maxWorkStart <- 10;
	int minWorkEnd <- 15;
	int maxWorkEnd <- 18;
	int minFreeTimeStart <- 16;
	int maxFreeTimeStart <- 19;
	int minFreeTimeEnd <- 21;
	int maxFreeTimeEnd <- 23;
	
	

	init {
		create road from: shp_roads;
		theGraph <- as_edge_graph(road);
		
		create district from: shp_districts with: [name::string(read("NAZWA"))] {
			
		}
		
		create object from: shp_objects with: [type::string(read("TYP")), needs::bool(read("POTRZEBA")), prize_num::float(read("NAGRODA"))
		]{
//			list<object> withNeeds <-  (type, prize) where needs;
			height <- 20 + rnd(200);
			
			if (prize_num > 0 and prize_num < 0.25) {
				prize <- "bilety_komunikacyjne";
			} else if (prize_num < 0.5) {
				prize <- "bilety_do_kina";
			} else if (prize_num < 0.75) {
				prize <- "kolejka_lekarz";
			} else {
				prize <- "szybciej_przedszkole";
			}
			
		}
		
		list<object> flats <- object where (each.type = "niska zabudowa");
		list<object> blocks <- object where (each.type = "blokowisko");
		list<object> offices <- object where (each.type = "biurowiec");
		list<object> factories <- object where (each.type = "fabryka");
		list<object> surgeries <- object where (each.type = "przychodnia");
		list<object> cultural_centers <- object where (each.type = "park" or each.type = "bulwary" or each.type = "zabytek");
		list<object> departments <- object where (each.type = "urzad");

		/* tworzenie agentów */
		create person from: shp_agents with: [id::int(read("ID")), age::float(read("AGE")), altruism::float(read("ALTRUISM")), 
			education::float(read("EDUCATION")), happiness::float(read("HAPPINESS")), wealth::float(read("WEALTH")), identity::float(read("IDENTITY")),
			isMarried::bool(read("MARRIED")), numOfChildren::int(read("CHILDREN")), engagement::float(read("ENGAGEMENT")) //married bool or int?
		]{
			objective <- "at_home";
			
			startWork <- minWorkStart + rnd((maxWorkStart - minWorkStart) * 60) / 60;
			endWork <- minWorkEnd + rnd((maxWorkEnd - minWorkEnd) * 60) / 60;
			startFreeTime <- minFreeTimeStart + rnd((maxFreeTimeStart - minFreeTimeStart) * 60) / 60;
			endFreeTime <- minFreeTimeEnd + rnd((maxFreeTimeEnd - minFreeTimeEnd) * 60) / 60;
			
			living <- flip(blockers) ? one_of(blocks) : one_of(flats);
			working <- flip(workers) ? one_of(factories) : one_of(offices);
			myDistrict <- district closest_to(location);
			playing <- one_of(cultural_centers);
		}
		

	}


		
	reflex update {
		ask person {
			ask one_of(objectInNeighbour) {
				if (self.needs = 1) {
					if (self overlaps myself) {
						if (myself.numOfChildren > 0) {
							if (self.prize = "szybciej_przedszkole") {
								myself.engagement <- myself.engagement + changeEngagementsMax;
							}
							else if (self.prize_num > 0) {
								myself.engagement <- myself.engagement + changeEngagementsAvg;
							}
				
						}
						else if (myself.wealth < 0.5) {
							if (self.prize = "kolejka_lekarz") {
								myself.engagement <- myself.engagement + changeEngagementsMax;
							}
							else if (self.prize_num > 0) {
								myself.engagement <- myself.engagement + changeEngagementsAvg;
							}
						
						}
						else if (self.prize_num > 0) {
							myself.engagement <- myself.engagement + changeEngagementsMin;
						}
					}
				}
			}
		}
	}

		
}

species road {
	aspect {
		draw shape color: #blue;
	}
}

species district {
	string name;
	aspect {
		draw shape color: #green;
	}
}

species object {
	string type;
	bool needs;
	float prize_num;
	string prize;
	int height;
//	list withNeeds;
	aspect {
		draw shape color: #red;
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
	float engagement;
	
	string objective;
	float startWork;
	float endWork;
	float startFreeTime;
	float endFreeTime;
	point myTarget;
	
	object living;
	object working;
	district myDistrict;
	object playing;
	
	list<object> objectInNeighbour update: object at_distance maxDistance;
	object currentPlace update: object closest_to(location);
	
	reflex home_work when: working != nil and objective = "at_home" and currentHour = startWork and currentDay <= 6 {
		objective <- "at_work";
		myTarget <- any_location_in(working);
	}
	
	reflex work_home when: living != nil and objective = "at_work" and currentHour = endWork {
		objective <- "at_home";
		myTarget <- any_location_in(living);
	}
	
	reflex home_play when: playing != nil and objective = "at_home" and currentHour = startFreeTime {
		objective <- "in_town";
		myTarget <- any_location_in(playing);
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

}

experiment first_experiment type: gui until: time = 180 {
//	reflex write_text {
//		write "Person " + person.id + " has engagement "+ person.engagement;
//	}
	output {
		display map type: opengl {
			species district;
			species object;
			species person;
		}

				
	}
}
