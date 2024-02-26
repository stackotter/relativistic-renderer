import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var tab = Tab._2d
    @State var onboardingState = OnboardingState.onboarding(.title)
    @State var titleOpacity: Double = 0
    
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
                case .title, .intro:
                    ZStack {
                        MetalView(error: Binding { nil } set: { _ in }, configuration: .default.with(\.introEffect, true)) {
                            try RenderCoordinator<RelativisticRenderer>.create(with: resources)
                        }
                        .ignoresSafeArea()
                        
                        if onboardingStep == .title {
                            VStack {
                                Text("Blackhole Playground")
                                    .font(.title)
                                Spacer().frame(height: 16)
                                Text("Explore the physics of light under extreme gravity")
                                Spacer().frame(height: 16)
                                HStack {
                                    Image(systemName: "rectangle.landscape.rotate")
                                    Text("Landscape mode is recommended")
                                }
                                Spacer().frame(height: 16)
                                Button("Begin") {
                                    onboardingState = .onboarding(.intro)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(16)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 8, height: 8)))
                            .opacity(titleOpacity)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1).delay(1)) {
                                    titleOpacity = 1
                                }
                            }
                        } else {
                            VStack(alignment: .leading) {
                                VStack(alignment: .leading) {
                                    Group {
                                        Text("General relativity")
                                            .font(.title)
                                        Text("Blackholes and the behaviour of other objects in their presence is best described by Einstein's Theory of General Relativity.")
                                        Text("Einstein's radical new way of describing gravity proposed that gravity isn't a force, it's the result of curvature in spacetime. The more massive an object, the more it curves spacetime.")
                                        Text("Einstein's equations are extremely difficult to solve in the general case, but a brilliant physicist Karl Schwarzschild found a solution that applies when you have a single spherical non-rotating mass. It's a simplification, but Schwarzschild's solution is widely applicable, especially when all other objects in a system are relatively small.")
                                        Text("Light")
                                            .font(.title)
                                        Text("Light has famously been shown to act as both a particle and wave, but at the scales that General Relativity applies, we can just treat it as a particle - the photon.")
                                        Text("Photons have no mass, but they're still affected by the curvature of spacetime due to their momentum. This gives rise to the strange appearance of blackholes.")
                                        Text("Blackholes")
                                            .font(.title)
                                        Text("A blackhole is an object that has collapsed under its own gravity into a single point in space. Not even light can escape beyond the point of no return - the event horizon.")
                                        Text("Accretion disks")
                                            .font(.title)
                                        Text("Blackholes often form extremely hot disks of gas that reach extreme temperatures and speeds. Contrary to how they may look, accretion disks truly are flat disks, but their light gets bent before it reaches your eyes and allows you to see the top and bottom of the disk at the same time.")
                                    }
                                    .padding(.bottom, 16)
                                }
                                Button("Next") {
                                    onboardingState = .onboarding(._2d)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .frame(maxWidth: 600)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding()
                        }
                    }
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
                                        onboardingState = .onboarding(._3d)
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
                    ZStack {
                        RenderView(resources: resources)
                        
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                VStack(alignment: .leading) {
                                    Group {
                                        Text("In 3d view you can move around a blackhole and observe how the blackhole's extreme gravity magnifies, and warps objects behind the blackhole, even allowing you to see parts of the accretion disk that would be hidden by the blackhole if not for light bending.")
                                        Text("For every pixel, a compute shader shoots a ray into the scene and computes a path similar to those you've seen in the 2d view, and figures out where light would have to come from to hit that pixel. If a ray reaches the event horizon, the pixel is black because no light would ever be able to reach the observer from within the event horizon.")
                                        Text("You may notice that as you change the raytracing settings the camera seems to zoom in or out. This is due to the error increasing/decreasing as you change the granularity of the raytracer.")
                                        HStack(alignment: .top) {
                                            Image(systemName: "slider.horizontal.3")
                                            Text("Configure the environment and raytracer in the sidebar")
                                        }
                                        HStack {
                                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                            Text("Drag to move the camera")
                                        }
                                    }
                                    .padding(.bottom, 16)
                                    
                                    Button("Done") {
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
