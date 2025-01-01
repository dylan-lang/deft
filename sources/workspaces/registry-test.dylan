Module: deft-test-suite

// The low-level LID parsing is done by the file-source-records library so this
// test is mainly concerned with whether parsing the "LID:" header works.
define test test-parse-lid-file--lid-header ()
  let parent-file
    = write-test-file("parent.lid", contents: "library: foo\nlid: child.lid\n");
  let child-file
    = write-test-file("child.lid", contents: "h1: v1\nh2: v2\n");
  let ws = make(<workspace>, directory: locator-directory(parent-file));
  let parent-lid = parse-lid-file(ws, #f, parent-file);
  assert-equal(2, parent-lid.lid-data.size);

  let sub-lids = lid-values(parent-lid, $lid-key) | #[];
  assert-equal(1, sub-lids.size);

  let child-lid = sub-lids[0];
  assert-equal(2, child-lid.lid-data.size);
  assert-equal("v1", lid-value(child-lid, #"h1"));
  assert-equal("v2", lid-value(child-lid, #"h2"));
end test;
