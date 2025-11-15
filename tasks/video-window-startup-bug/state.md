# Task State — Video Window Startup Bug

- Research complete: we traced the early VIDEO display to the eager `setupVideoWindowObserver()` call inside `WindowCoordinator.init`. It orders the window front whenever `settings.showVideoWindow` is `true`, regardless of whether the main presentation sequence has run.  
- Pending work: decide whether to defer the observer or gate `showVideo()` so the video window cannot appear before `presentInitialWindows()`.  
- No code changes applied yet; awaiting approval on the proposed plan before implementation.
