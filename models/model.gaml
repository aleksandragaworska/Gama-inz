/***
* Name: model
* Author: olaga
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model grywalizacja

/* Insert your model definition here */

global {
	float step <- 90 # mn;
	
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
		list<object> offices <- object where (each.type = "biurowiec");
		list<object> factories <- object where (each.type = "fabryka");
		list<object> surgeries <- object where (each.type = "przychodnia");
		list<object> cultural_centers <- object where (each.type = "park" or each.type = "bulwary" or each.type = "zabytek");
		list<object> departments <- object where (each.type = "urzad");
		list<object> schools <- object where (each.type = "szkola");

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
			
			speed <- minSpeed + rnd(maxSpeed - minSpeed) #km/#h;
			
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
							else if (self.prize_num > 0.1) {
								myself.engagement <- myself.engagement + changeEngagementsAvg;
							}
				
						}
						else if (myself.wealth < 0.5) {
							if (self.prize = "kolejka_lekarz") {
								myself.engagement <- myself.engagement + changeEngagementsMax;
							}
							else if (self.prize_num > 0.1) {
								myself.engagement <- myself.engagement + changeEngagementsAvg;
							}
						
						}
						else if (self.prize_num > 0.1) {
							myself.engagement <- myself.engagement + changeEngagementsMin;
						}
					}
				}
			}
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
	float engagement;
	
	string objective;
	float startWork;
	float endWork;
	float startFreeTime;
	float endFreeTime;
	float speed;
	point myTarget;
	
	object living;
	object working;
	district myDistrict;
	object playing;
	
	aspect base {
		draw circle(10) color: #yellow;
	}
	
	list<object> objectInNeighbour update: object at_distance maxDistance;
	object currentPlace update: object closest_to(location);
	
	reflex home_work when: working != nil and objective = "at_home" and currentHour = startWork and currentDay < 5 {
		objective <- "at_work";
		myTarget <- any_location_in(working);
	}
	
	reflex work_home when: living != nil and objective = "at_work" and currentHour = endWork {
		objective <- "at_home";
		myTarget <- any_location_in(living);
	}
	
	reflex home_play when: playing != nil and objective = "at_home" and ((currentHour = startFreeTime and currentDay < 5) or (currentDay > 4 and currentHour > 8)) {
		objective <- "in_town";
		myTarget <- any_location_in(playing);
	}
	
	reflex play_home when: living != nil and objective = "in_town" and currentHour = endFreeTime {
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

				
	}
}
