import SwiftUI

// TODO: Add pretty on-boarding screen and make sure to explain controls during on-boarding
// TODO: Fix tearing (by double/triple buffering the config buffer)
// TODO: Implement intuitive 3d movement controls
// TODO: Fix other TODOs scattered around
// TODO: Maybe bloom?
// TODO: Make the accretion disk off axis perhaps?
// TODO: Make gravity's effect on light toggleable
// TODO: Fix clip shape of torch
// TODO: Move default position of 2d diagram for onboarding overlay to not overlap with it
// TODO: Make the number of steps a log scale
// TODO: Make accretion disk start/end sliders not change ranges (just limit movement instead)
// TODO: Clean up onboarding code
// TODO: Cool onboarding animation

@main
struct BlackholePlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
