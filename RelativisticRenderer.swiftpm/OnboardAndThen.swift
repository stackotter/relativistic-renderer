import SwiftUI

struct OnboardAndThen<Child: View>: View {
    var resources: RelativisticRenderer.Resources
    @ViewBuilder var child: () -> Child
    
    @State var onboardingState = OnboardingState.onboarding(.title)
    @State var titleOpacity: Double = 0
    
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
    
    let introduction = Introduction(
        sections: [
            Introduction.Section(
                title: "General relativity",
                paragraphs: [
                    "Blackholes and the behaviour of other objects in their presence is best described by Einstein's Theory of General Relativity.",
                    "Einstein's radical new way of describing gravity proposed that gravity isn't a force, it's the result of curvature in spacetime. The more massive an object, the more it curves spacetime.",
                    "Einstein's equations are extremely difficult to solve in the general case, but a brilliant physicist Karl Schwarzschild found a solution that applies when you have a single spherical non-rotating mass. It's a simplification, but Schwarzschild's solution is widely applicable, especially when all other objects in a system are relatively small."
                ]
            ),
            Introduction.Section(
                title: "Light",
                paragraphs: [
                    "Light has famously been shown to act as both a particle and wave, but at the scales that General Relativity applies, we can just treat it as a particle - the photon.",
                    "Photons have no mass, but they're still affected by the curvature of spacetime due to their momentum. This gives rise to the strange appearance of blackholes."
                ]
            ),
            Introduction.Section(
                title: "Blackholes",
                paragraphs: ["A blackhole is an object that has collapsed under its own gravity into a single point in space. Not even light can escape beyond the point of no return - the event horizon."]
            ),
            Introduction.Section(
                title: "Accretion disks",
                paragraphs: ["Blackholes often form extremely hot disks of gas that reach extreme temperatures and speeds. Contrary to how they may look, accretion disks truly are flat disks, but their light gets bent before it reaches your eyes and allows you to see the top and bottom of the disk at the same time."]
            )
        ]
    )
    
    let instructionPanel2d = InstructionPanel(
        paragraphs: [
            "In 2d view you can move a light source around a blackhole and observe how the rays of light are affected by the blackhole's extreme gravity.",
            "The rays are traced by solving Schwarzschild's solution with a numerical integration method."
        ],
        legend: [
            ("slider.horizontal.3", "Increase the number of steps to increase precision, and increase the maximum revolutions to increase the maximum number of times that light will be followed around the blackhole."),
            ("arrow.up.and.down.and.arrow.left.and.right", "Drag the torch to move it"),
            ("arrow.up.and.down.and.arrow.left.and.right", "Drag anywhere else to move the camera"),
            ("arrow.down.left.and.arrow.up.right", "Pinch to zoom")
        ]
    )
    
    let instructionPanel3d = InstructionPanel(
        paragraphs: [
            "In 3d view you can move around a blackhole and observe how the blackhole's extreme gravity magnifies, and warps objects behind the blackhole, even allowing you to see parts of the accretion disk that would be hidden by the blackhole if not for light bending.",
            "For every pixel, a compute shader shoots a ray into the scene and computes a path similar to those you've seen in the 2d view, and figures out where light would have to come from to hit that pixel. If a ray reaches the event horizon, the pixel is black because no light would ever be able to reach the observer from within the event horizon.",
            "You may notice that as you change the raytracing settings the camera seems to zoom in or out. This is due to the error increasing/decreasing as you change the granularity of the raytracer."
        ],
        legend: [
            ("slider.horizontal.3", "Configure the environment and raytracer in the sidebar"),
            ("arrow.up.and.down.and.arrow.left.and.right", "Drag to move the camera"),
        ]
    )

    var body: some View {
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
                            withAnimation(.easeInOut(duration: 1).delay(0.5)) {
                                titleOpacity = 1
                            }
                        }
                    } else {
                        VStack(alignment: .leading) {
                            ScrollView {
                                VStack(alignment: .leading) {
                                    introduction
                                }
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
                    DiagramView(tab: nil)
                    
                    InstructionPanelOverlay(panel: instructionPanel2d) {
                        onboardingState = .onboarding(._3d)
                    }
                }
            case ._3d:
                ZStack {
                    RenderView(tab: nil, resources: resources)
                    
                    InstructionPanelOverlay(panel: instructionPanel3d) {
                        onboardingState = .done
                    }
                }
            }
        case .done:
            child()
        }
    }
}

extension OnboardAndThen {
    struct Introduction: View {
        var sections: [Section]
        
        struct Section {
            var title: String
            var paragraphs: [String]
        }
        
        var body: some View {
            ForEach(sections, id: \.title) { section in
                Text(section.title)
                    .font(.title)
                    .padding(.bottom, 16)
                ForEach(section.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .padding(.bottom, 16)
                }
            }
        }
    }
}

extension OnboardAndThen {
    struct InstructionPanel: View {
        var paragraphs: [String]
        var legend: [(icon: String, description: String)]
        
        var body: some View {
            Group {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
                ForEach(legend, id: \.description) { (icon, description) in
                    HStack {
                        Image(systemName: icon)
                        Text(description)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}

extension OnboardAndThen {
    struct InstructionPanelOverlay: View {
        var panel: InstructionPanel
        var next: () -> Void
        
        var body: some View {
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    VStack(alignment: .leading) {
                        panel
                        
                        Button("Next") {
                            next()
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
}
