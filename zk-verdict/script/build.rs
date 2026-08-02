use sp1_build::build_program_with_args;

fn main() {
    // The predicate guest (trusts `post`) and the full re-execution guest
    // (executes revm in-guest to derive `post`).
    build_program_with_args("../program", Default::default());
    build_program_with_args("../program-revm", Default::default());
    build_program_with_args("../program-svm", Default::default());
}
