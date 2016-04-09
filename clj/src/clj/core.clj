(ns clj.core
  (:gen-class
   :name Core ))


(defn full [functions function-args terminals level maxlevels]
  "Creates a program tree that is a full tree (all terminal leaves are on the same level)."
  ;gets a random index in the function vector
  (let [rnd-func-idx (rand-int (count functions))]
    (if (not= level maxlevels)
      ;preappend the randomly picked function to a list of arguments
      (cons (nth functions rnd-func-idx) (loop [args 0 arg-count (nth function-args rnd-func-idx) arg-list '()] 
        (if (not= args arg-count)
          ;make a full tree of one level smaller and preappend that to the argument list
          (recur (+ 1 args) arg-count (cons (full functions function-args terminals (+ 1 level) maxlevels) arg-list))
           arg-list)))
      ;return one of the terminals at the bottom level
      (nth terminals (rand-int (count terminals))))))

(defn grow [functions function-args terminals level maxlevels]
  "Creates a programm tree by 'growing it' from the root and has randomness to the breadth and depth"
  ;if anot at bottom, grow
  (if (not= level maxlevels)
    ;if the root level or if a random int is above 1 (80% chance), must be a function
    (if (or (= level 1) (> (rand-int 9) 1))
      (let [rnd-func-idx (rand-int (count functions))]
        ;preappend the chosen function to the arguemnt list
        (cons (nth functions rnd-func-idx) (loop [args 0 arg-count (nth function-args rnd-func-idx) arg-list '()]
          (if (not= args arg-count)
            ;generate the argument list by recurively calling grow
            (recur (+ 1 args) arg-count (cons (grow functions function-args terminals (+ 1 level) maxlevels) arg-list))
            arg-list))))
      (nth terminals (rand-int (count terminals))))
    (nth terminals (rand-int (count terminals)))))

(defn rhah [functions function-args terminals population-size max-tree-size]
  "creates an initial generation using 'ramped half and half'.  Ramped refers to how it starts with small trees and increases the tree sizes and half and half refers to using grow and full equally"
  (let [programs-per-size (/ population-size (- max-tree-size 1))] ;divide populationsize by number of possible sizes for number of programs of that size per tree
    (loop [size 2 program-list '[]] ;loop while size is less than max
      (if (<= size max-tree-size)
        (recur (+ size 1) (into [] (concat (loop [num-this-size 1 inner-list program-list] ;loop for (pop-size/max-tree-size) percent of the total population
          (if (<= num-this-size programs-per-size)
            (recur (+ num-this-size 1) (cons (if (= (mod num-this-size 2) 0) ;preappend either a grow or a full tree to the list of programs
              (grow functions function-args terminals 1 size)
              (full functions function-args terminals 1 size)) inner-list))
            inner-list)) program-list))) ;concat the list of programs generated for that size with the rest of the generated programs
        program-list)))) 

(defrecord ProgramFitness [program raw standardized adjusted normalized])

(defn gen-zero [functions function-args terminals population-size max-tree-size]
  "creates a vector of program-fitness structures and fills the program field with programs generated from rhah"
  (into [] (map #(ProgramFitness. % nil nil nil nil) (rhah functions function-args terminals population-size max-tree-size) ))) 

(defn raw-fitnes [programs fitness-function] 
  "evaluates the raw fitness of each program using the fitness function"
  (into [] (map #(assoc % :raw (fitness-function (get % :program))) programs)))




(defn -main
  "I don't do a whole lot ... yet."
  [& args]
  (let [functions '[+ - *] function-args '[2 2 2] terminals '[1 2 3 4 5 6 7 8 9]]
        (let [funs (gen-zero functions function-args terminals 50 6)]
          (prn funs)
          (prn (raw-fitnes funs #(Fitness/fitness %))))))

