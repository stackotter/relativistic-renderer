import SwiftUI

struct ContentView: View {
    @State var tab = Tab._2d
    @State var onboardingState = OnboardingState.onboarding(.title)
    
    enum Tab: Hashable {
        case _2d
        case _3d
    }
    
    enum OnboardingState {
        case onboarding(OnboardingStep)
        case done
    }
    
    enum OnboardingStep: CaseIterable {
        case title
        case intro
        case _2d
        case _3d
    }
    
    var body: some View {
        // Shaders are loaded upfront since they are compiled at runtime instead of compile time in
        // this playground
        Await(RelativisticRenderer.loadResources) {
            Text("Loading")
        } success: { resources in
            switch onboardingState {
            case .onboarding(let onboardingStep):
                switch onboardingStep {
                case .title:
                    VStack {
                        Text("Blackhole Playground")
                            .font(.title)
                        Spacer().frame(height: 16)
                        Text("Explore the physics of light under extreme gravity")
                        Spacer().frame(height: 16)
                        Button("Begin") {
                            onboardingState = .onboarding(.intro)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .intro:
                    VStack(alignment: .leading) {
                        Group {
                            Text("General relativity")
                                .font(.title)
                            Text("Blackholes and the behaviour of other objects in their presence is best described by Einstein's Theory of General Relativity.")
                            Text("Einstein's radical new way of describing gravity proposed that gravity isn't a force, it's the result of curvature in spacetime. The more massive an object, the more it curves spacetime.")
                            Text("Einstein's equations themselves are extremely difficult to solve in the general case, but a brilliant physicist Karl Schwarzschild found a solution that applies when you have a single spherical non-rotating mass. Although it's a simplification, Schwarzschild's solution is widely applicable, especially when all other objects involved in your system have insignificant effects on the curvature of spacetime.")
                            Text("Light")
                                .font(.title)
                            Text("Light has famously been shown to act as both a particle and wave, but at the scales that General Relativity applies, we can just treat it as a particle - the photon.")
                            Text("Photons have no mass, but they're still affected by the curvature of spacetime due to their momentum. This gives rise to the existence of blackholes.")
                            Text("Light is particularly strange under General Relativity; no matter how fast you're moving, light always seems to travel at the same speed relative to you, and photons themselves do not experience the passage of time.")
                            Text("Blackholes")
                                .font(.title)
                            Text("A blackhole is an object that has become so dense that not even light can escape. If an object is compressed to fit within its Schwarzschild radius, it forms a blackhole. The Schwarzschild radius is the threshold beyond which no object can possibly prevent itself from collapsing into a single point in space (although the 'single point', or singularity, part is still debated to this day).")
                        }
                        .padding(.bottom, 16)
                        Button("Next") {
                            onboardingState = .onboarding(._2d)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(width: 800)
                case ._2d:
                    ZStack {
                        DiagramView()
                        
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                VStack(alignment: .leading) {
                                    Group {
                                        Text("In 2d view you can move a light source around a blackhole and observe how the rays of light are affected by the blackhole's extreme gravity.")
                                        Text("The rays are traced by solving Schwarzschild's solution with a numerical integration method.")
                                        HStack(alignment: .top) {
                                            Image(systemName: "slider.horizontal.3")
                                            Text("Increase the number of steps to increase precision, and increase the maximum revolutions to increase the maximum number of times that light will be followed around the blackhole.")
                                        }
                                        HStack {
                                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                            Text("Drag the torch to move it")
                                        }
                                        HStack {
                                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                            Text("Drag anywhere else to move the camera")
                                        }
                                        HStack {
                                            Image(systemName: "arrow.down.left.and.arrow.up.right")
                                            Text("Pinch to zoom")
                                        }
                                    }
                                    .padding(.bottom, 16)
                                    
                                    Button("Next") {
//                                        onboardingState = .onboarding(._3d)
                                        onboardingState = .done
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))
                                .frame(width: 600)
                                .offset(x: -16, y: -16)
                            }
                        }
                    }
                case ._3d:
                    Text("TODO")
                }
            case .done:
                TabView(selection: $tab) {
                    DiagramView()
                        .tabItem {
                            Text("2d")
                        }
                        .tag(Tab._2d)
                    
                    RenderView(resources: resources)
                        .tabItem {
                            Text("3d")
                        }
                        .tag(Tab._3d)
                }
            }
        } failure: { error in
            Text("Failed to load resources: \(error.localizedDescription)")
        }
    }
}
