#!/usr/bin/python

# This is an old check that fails for one case
def check(idx1,idx2,en1,en2,prio1,prio2,avoid):
	if not (avoid == idx2 or en2 == 0) and (avoid == idx1 or en1 == 0 or prio2 > prio1):
			return idx2
	return idx1

# This is the new correct check
def check(idx1,idx2,en1,en2,prio1,prio2,avoid):
	if avoid == idx1 or (avoid != idx2 and en2 == 1 and (en1 == 0 or prio2 > prio1)):
		return idx2
	return idx1



idx1 = 5
idx2 = 8
other = 3
assert check(idx1,idx2, en1=0, en2=0, prio1=2,prio2=1, avoid=other) == idx1
assert check(idx1,idx2, en1=0, en2=0, prio1=2,prio2=1, avoid=idx2) == idx1
assert check(idx1,idx2, en1=0, en2=0, prio1=2,prio2=1, avoid=idx1) == idx2

assert check(idx1,idx2, en1=0, en2=1, prio1=2,prio2=1, avoid=other) == idx2
assert check(idx1,idx2, en1=0, en2=1, prio1=2,prio2=1, avoid=idx2) == idx1
assert check(idx1,idx2, en1=0, en2=1, prio1=2,prio2=1, avoid=idx1) == idx2

assert check(idx1,idx2, en1=1, en2=0, prio1=2,prio2=1, avoid=other) == idx1
assert check(idx1,idx2, en1=1, en2=0, prio1=2,prio2=1, avoid=idx2) == idx1
assert check(idx1,idx2, en1=1, en2=0, prio1=2,prio2=1, avoid=idx1) == idx2

assert check(idx1,idx2, en1=1, en2=1, prio1=2,prio2=1, avoid=other) == idx1
assert check(idx1,idx2, en1=1, en2=1, prio1=2,prio2=1, avoid=idx2) == idx1
assert check(idx1,idx2, en1=1, en2=1, prio1=2,prio2=1, avoid=idx1) == idx2


# Same cases with priorities swapped
assert check(idx1,idx2, en1=0, en2=0, prio1=1,prio2=2, avoid=other) == idx1
assert check(idx1,idx2, en1=0, en2=0, prio1=1,prio2=2, avoid=idx2) == idx1
assert check(idx1,idx2, en1=0, en2=0, prio1=1,prio2=2, avoid=idx1) == idx2

assert check(idx1,idx2, en1=0, en2=1, prio1=1,prio2=2, avoid=other) == idx2
assert check(idx1,idx2, en1=0, en2=1, prio1=1,prio2=2, avoid=idx2) == idx1
assert check(idx1,idx2, en1=0, en2=1, prio1=1,prio2=2, avoid=idx1) == idx2

assert check(idx1,idx2, en1=1, en2=0, prio1=1,prio2=2, avoid=other) == idx1
assert check(idx1,idx2, en1=1, en2=0, prio1=1,prio2=2, avoid=idx2) == idx1
assert check(idx1,idx2, en1=1, en2=0, prio1=1,prio2=2, avoid=idx1) == idx2

assert check(idx1,idx2, en1=1, en2=1, prio1=1,prio2=2, avoid=other) == idx2
assert check(idx1,idx2, en1=1, en2=1, prio1=1,prio2=2, avoid=idx2) == idx1
assert check(idx1,idx2, en1=1, en2=1, prio1=1,prio2=2, avoid=idx1) == idx2


print("All testcases were successful.")