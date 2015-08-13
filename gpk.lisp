;;; stuff pertaining to generating program trees for the initial population
(defun full (funcs funcargmap terms level size)
	"creates a program tree using the full method and recursive preorder traversal"
	(setq func (random (length funcs)))
	(if (/= level size)
		(CONS (NTH func funcs) (loop for x from 1 to (nth func funcargmap) collect (full funcs funcargmap terms (+ level 1) size)))
		(nth (random (length terms)) terms)
	)
)
(defun grow (funcs funcargmap terms level size)
	"creates a program tree using the grow method and recursive preorder traversal"
	;pick a node randomly from set of functions and terminals
	(setq funcsandterms (append funcs terms))
	(setq node (random (length funcsandterms)))
	(if (/= level size)
		;if not at max size
		(if (= 1 level)
			;if at root, make a function
			(CONS (NTH (mod node (length funcs)) funcs) (loop for x from 1 to (nth (mod node (length funcs)) funcargmap) collect (grow funcs funcargmap terms (+ level 1) size)))
			;if not at root, choose node from terminals and functions
			(if (< node (length funcs))
				;if an operator, generate children 
				(CONS (NTH node funcs) (loop for x from 1 to (nth node funcargmap) collect (grow funcs funcargmap terms (+ level 1) size)))
				;if a terminal, put terminal
				(nth node funcsandterms)
			)
		)
		;if at amx size, make a termina
		(nth (random (length terms)) terms)
	)	
)
(defun rhah (funcs funcargmap terms popsize maxsize)
	"creates an initial generation of programs using the 'ramped half-and-half' method (thus rhah)"
	(setq result ()) ;an initial empty list
	(setq numpersize (/ popsize (- maxsize 1))) ;sets number of programs per size to be equal percentages
	(loop for size from 2 to maxsize ; for each program size
		do(
			loop for program from 1 to numpersize ;for each program of this size
				do (
					if (= (mod program 2) 0) ;alternate between full and grow methods
						(setq result (cons (full funcs funcargmap terms 1 size) result))
						(setq result (cons (grow funcs funcargmap terms 1 size) result))
				)
		)	
	)
	result
	
)
(defun first-gen (functions argument-map terminals pop-size max-size)
	"creates an array of program-fitness structures from the rhah method"
	(setq first-gen (make-array pop-size))
	(setq x 0)
	(dolist (n (rhah functions argument-map terminals pop-size max-size)) ;loops through results from rhah and adds to array
		(setf (aref first-gen x) (make-program-fitness :prog n))
		(incf x 1)
	)
	first-gen
)
;;; stuff pertaining to fitness
(defstruct program-fitness
	"Defines a structure for holding a program and its associated fitnesses" 
	prog
	raw
	std
	adj
	nrm
)
(defun rawfitness (programs fit-func)
	"Takes an array of program-fitness structures with the prog  filled in and fills in raw field. 
	Also takes the fitness function being used"
	(setq raw-arr (make-array (nth 0 (array-dimensions programs))))
	(dotimes (x (nth 0 (array-dimensions programs)))
		(setf (aref raw-arr x) (make-program-fitness :prog (program-fitness-prog (aref programs x))))
		(setf (program-fitness-raw (aref raw-arr x)) (funcall fit-func (program-fitness-prog (aref programs x)))) ;sets raw fitness according to passed in fitness function
	)
	raw-arr

)
(defun stdfitness (rawfitness bestValue)
	"Function that takes an array ofprogram-fitness structures with raw fitness filled in and converts it to standardized fitness. The first argument is jsut that raw fitness.
	The second argument is the best possible value. If the raw fitness is lowest is best, 
	then give this parameter 0. If highest is best, then give it the best value. 
	If Highest is best and the best value is unknown, use an arbitrarily high value"
	(setq std-arr (make-array (nth 0 (array-dimensions rawfitness))))
	(dotimes (x (nth 0 (array-dimensions rawfitness)))
		(setq rawfit (program-fitness-raw (aref rawfitness x))) ;get the raw fitness of the element
		(setq stdfit (abs (- bestValue rawfit)))
		(setf (aref std-arr x) (make-program-fitness :prog (program-fitness-prog (aref rawfitness x)) :raw rawfit :std stdfit))
	)
	std-arr
)
(defun adjfitness (stdfitness) 
	"Function that takes an array of program-fitness structures with std filled in and converts it to adjusted fitness."
	(setq adj-arr (make-array (nth 0 (array-dimensions stdfitness))))
	(dotimes (x (nth 0 (array-dimensions stdfitness)))
		(setq stdfit (program-fitness-std (aref stdfitness x))) ;get the std fitness of the element
		(setq adjfit (/ 1 (+ 1 stdfit)))
		(setf (aref adj-arr x) (make-program-fitness :prog (program-fitness-prog (aref stdfitness x)) :raw (program-fitness-raw (aref stdfitness x)) :std stdfit :adj adjfit))
	)
	adj-arr
	
)
(defun nrmfitness (adjfitness)
	"takes an array of program-fitness structures with adj filled in. puts out the normalized, or proportional fitness of that value"
	(setq sum-adjfitness 0)
	(setq nrm-arr (make-array (nth 0 (array-dimensions adjfitness))))
	(dotimes (x (nth 0 (array-dimensions adjfitness)))
		(incf sum-adjfitness (program-fitness-adj (aref adjfitness x)))
	)
	(dotimes (x (nth 0 (array-dimensions adjfitness)))
		(setq adjfit (program-fitness-adj (aref adjfitness x)))
		(setq nrmfit (/ adjfit sum-adjfitness))
		(setf (aref nrm-arr x) (make-program-fitness :prog (program-fitness-prog (aref adjfitness x)) :raw (program-fitness-raw (aref adjfitness x)) :std (program-fitness-std (aref adjfitness x)) :adj adjfit :nrm nrmfit))
	)
	nrm-arr
)
(defun sort-fit-first (programs)
	"Takes an array of fully filled program-fitness structures and sorts them such that the most fit are first. uses insertion sort"
	(loop for i from 1 to (- (nth 0 (array-dimensions programs)) 1) 

		do (setq x (aref programs i))
		do (setq j i)
		do (loop while (and (> j 0) (> (program-fitness-nrm (aref programs (- j 1))) (program-fitness-nrm x))) 
			do (setf (aref programs j) (aref programs (- j 1)))
			do (decf j 1)
		)
		do (setf (aref programs j) x)

	)
	programs

)
(defun fit-and-sort (programs fit-func bestValue)
	"Ties together all of the functions nessesary for preparing programs for selection"
	(setq prog-ar (rawfitness programs fit-func))
	(setq prog-ar (stdfitness prog-ar bestValue))
	(setq prog-ar (adjfitness prog-ar))
	(setq prog-ar (nrmfitness prog-ar))
	(sort-fit-first prog-ar)
	;;correct if the sum of nrm fitness is slightly off from 1
	(setq sum 0)
	(dotimes (n (nth 0 (array-dimensions prog-ar))) 
		(incf sum (program-fitness-nrm (aref prog-ar n)))
	)
	(setq off-from-one (- sum 1)) ;will be positive if sum > 1 and negative if sum < 1
	(setq most-fit-nrm (program-fitness-nrm (aref prog-ar (- (nth 0 (array-dimensions prog-ar)) 1)))) ;most fit nrm is nrm fitness of last program in array
	(setf (program-fitness-nrm (aref prog-ar (- (nth 0 (array-dimensions prog-ar)) 1))) (+ most-fit-nrm off-from-one)) ;add off from one
	prog-ar
)

;;; stuff pertaining to creating a new generation
(defun pick-individual (programs)
	"Takes an array of fully filled out program-fitness structures and selects a single individual 
	from the population based on the fitness probability (normalized fitness)"
	(setq rnd (random 1.0)) 
	(setq idx (nth 0 (array-dimensions programs))) ;sets the index to the most fit individual
	(loop while (>= rnd 0)
		do (decf idx 1)
		do (decf rnd (program-fitness-nrm (aref programs idx)))
	)
	(aref programs idx)
)
(defun get-good-cross-point (program)
	"function that takees a single program as an argument and finds a point for crossover to occur such that a leaf has 
	a 10% chance of being chosen as the cross point and a non-leaf has a 90% chance."
	(if (= 1 (length program))
		(return-from get-good-cross-point 0)
		nil
	)
	(setq traversed 0)
	(setq queue (list program))

	;; these two lists are going to hold the breadth first locations of the tree nodes. they are sepatrated by 
	;; leaves and non-leaves so i can more easily have different probabilities for selecting a leaf or a node
	(setq leaves nil)
	(setq non-leaves nil)

	(loop while (/= 0 (length queue)) ; while queue is not empty
		do (setq current (car queue)) ; dequeue
		do (setq queue (cdr queue))

		do (if (atom current)
			(setq leaves (append leaves (list traversed)))
			(progn (dolist (x (cdr current))
					(setq queue (append queue (list x)))
				)
				(setq non-leaves (append non-leaves (list traversed)))
			)
		)
		do (incf traversed 1)
	)
	(if (= 0 (random 10)) ; (random 10) == 0 is a 10% chance
		(nth (random (length leaves)) leaves) ;pick random leaf (10%)
		(nth (random (length non-leaves)) non-leaves) ;pick random non-leaf (90%)
	)

)

(defun get-nth-subtree (program n)
	"Gets the nth subtree of the given program returns program subtree. This is done in a breadth first way, so the whole program 
	is n == 0, the program's first child is 1, second child is 2, etc."
	(if (= n 0) (return-from get-nth-subtree program) nil)
	(setq traversed 0)
	(setq queue (list program))
	(loop while (/= 0 (length queue)) ; while queue is not empty
		do (setq current (car queue)) ; dequeue
		do (setq queue (cdr queue))

		do (if (atom current)
			nil ;atoms are leaves. nothing to do
			(dolist (x (cdr current))
				(setq queue (append queue (list x)))
				(incf traversed 1)
				(if (= traversed n)
					(return-from get-nth-subtree x)
					nil
				)
			)
		)
	)
	nil ;shouldnt make it here
)

(defun set-nth-subtree (program-in n subtree)
	"sets the nth subtree of the given program with the given subtreei. does not modify the given program and instead returns a modified copy"
	(setq program (copy-tree program-in))
	(if (= n 0) 
		(return-from set-nth-subtree (if (atom subtree) 
							subtree 
							(progn (setf (car program) (car subtree)) (setf (cdr program) (cdr subtree)))
						)
		) 
		nil
	)
	(setq traversed 0)
	(setq queue (list program))
	(loop while (/= 0 (length queue)) ; while queue is not empty
		do (setq current (car queue)) ; dequeue
		do (setq queue (cdr queue))
		do (setq idx 1)
		do (if (atom current)
			nil ;atoms are leaves. nothing to do
			(dolist (x (cdr current))
				(setq queue (append queue (list x)))
				(incf traversed 1)
				(if (= traversed n)
					(setf (nth idx current) subtree)
					nil
				)
				(incf idx 1)
			)
		) 
	)
	program
)
(defun crossover (parent1 parent2)
	"performs the crossover operation on the given parents.  This function does not modify tihe given programs, and returns a list with the children in it"
	
	(setq p1-copy (copy-tree parent1))
	(setq p2-copy (copy-tree parent2))	

	(setq cross-point-1 (get-good-cross-point parent1))
	(setq cross-point-2 (get-good-cross-point parent2))

	(setq swap-1 (get-nth-subtree parent1 cross-point-1))
	(setq swap-2 (get-nth-subtree parent2 cross-point-2))

	(set-nth-subtree p1-copy cross-point-1 swap-2)
	(set-nth-subtree p2-copy cross-point-2 swap-1)
	
	(list p1-copy p2-copy)
)
(defun next-gen (programs)
	"Takes an array of fully filled out program-fitness structures and returns an array of program-fitness structures that
	holds the next generation.  Structures that were the result of asexual reproduction will still have fitness calculated for them.
	Structures that are the result of crossover will not, and all fitness values will be nil"
	(setf next-gen (make-array (nth 0 (array-dimensions programs)))) ;creates next gen array
	(setq n 0)
	(setq reprouction-times (ceiling (* (nth 0 (array-dimensions programs)) .1))) ; a bit over 10% of next-gen is asexual reproduction
	(setq crossover-times (floor (* (nth 0 (array-dimensions programs)) .9))) ; a bit under 90% of next-gen is crossover
	(if (/= 0 (mod crossover-times 2)) ;if not an even number of crossover times, give one to reproduction times
		(progn (incf reprouction-times 1) (decf crossover-times 1))
		nil
	)
	;; do reproduction
	(loop while (< n reprouction-times)
		do (setf (aref next-gen n) (pick-individual programs)) ;picks an individual from last gen based on fitness and puts in next gen
		do (incf n 1)
	)
	(setq n 0)
	;; do crossover
	(loop while (< n crossover-times)
		do (let ((parent1 (program-fitness-prog (pick-individual programs))) ;pick two parents for crossover based on fitness
			 (parent2 (program-fitness-prog (pick-individual programs))))
			(setq crossed (crossover parent1 parent2)) ;perform crossover
			(setf (aref next-gen (+ n reprouction-times)) (make-program-fitness :prog (nth 0 crossed)))
			(incf n 1)
			(setf (aref next-gen (+ n reprouction-times)) (make-program-fitness :prog (nth 1 crossed)))

		)
		do (incf n 1)
	)
	;; done
	next-gen
)
(defun just-do-it (functions argmap terminals pop-size max-depth fit-func best-value generations)
	"runs the whole thing for the specified number of generations and returns a list with the first element being the best of run result and the second element being the best of generation result"
	(setq best-of-run nil)
	(setq best-of-generation nil)
	;;make gen 0
	(setq gen (first-gen functions argmap terminals pop-size max-depth))
	;;loop through all generations
	(dotimes (n generations)
		;;eval fitness
		(setq gen (fit-and-sort gen fit-func best-value))
		;;get best of generation, see if has best of run
		(setq best-of-generation (aref gen (- pop-size 1)))
		(if (= 0 n)
			(setq best-of-run best-of-generation) ; first run, there is no best of run yet
			(if (< (program-fitness-std best-of-run) (program-fitness-std best-of-generation))
				(setq best-of-run best-of-generation) ; best of generation is better
				nil ; best of run is better, do nothing
			)
		)
		;;check if best result is found
		(if (= best-value (program-fitness-raw best-of-run))
			(return-from just-do-it (list best-of-run best-of-generation))
			nil
		)
		;;create next gen
		(setq gen (next-gen gen))	
	)
	(list best-of-run best-of-generation gen)
)
