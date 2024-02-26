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
                    "Einstein's radical new way of describing gravity proposed that gravity is the result of curvature in spacetime. The more massive an object, the more it curves spacetime.",
                    "Einstein's equations are extremely difficult to solve in the general case, but the brilliant physicist Karl Schwarzschild found a solution that applies when you have a single spherical non-rotating mass. It's a simplification, but Schwarzschild's solution is accurate enough in many situations."
                ]
            ),
            Introduction.Section(
                title: "Light",
                paragraphs: [
                    "Light is famously both a particle and wave, but under General Relativity, we just treat it as a particle - the photon.",
                    "Photons have no mass, but they're still affected by the curvature of spacetime due to their momentum. This gives rise to the strange appearance of blackholes."
                ]
            ),
            Introduction.Section(
                title: "Blackholes",
                paragraphs: ["A blackhole is an object that has collapsed under its own gravity into a single point in space. Not even light can escape beyond the point of no return - the event horizon."]
            ),
            Introduction.Section(
                title: "Accretion disks",
                paragraphs: ["Blackholes often form extremely hot disks of gas that reach extreme temperatures and speeds. Contrary to how they may look, accretion disks truly are flat disks, but their light gets bent before it reaches your eyes allowing you to see the top and bottom of the disk at the same time."]
            ),
            Introduction.Section(
                title: "Raytracing",
                paragraphs: [
                    "Raytracing is one of the two main ways that computers render scenes (the other being rasterization). Raytracing involves tracing the path of light (backwards) to figure out which colour of light could have reached a particular pixel of your virtual camera.",
                    "Raytracers generally assume that light travels in straight lines, but as you now know, it doesn't always! The raytracer you'll see in the 3d view has been specifically designed to incorporate the effects of general relativity while tracing the path of light through the scene.",
                    "You may notice that as you change the raytracing settings the camera seems to zoom in or out. This is due to the error increasing/decreasing as you change the granularity of the raytracer."
                ]
            )
        ]
    )
    
    let instructionPanel2d = InstructionPanel(
        paragraphs: [
            "In 2d view you can move a light source around a blackhole and observe how the rays of light are affected by the blackhole's extreme gravity.",
            "The rays are traced by solving Schwarzschild's solution with a numerical integration method."
        ],
        legend: [
            ("slider.horizontal.3", "Use the sidebar to configure the number of raytracing steps, the number of times that light will get followed around the blackhole (for performance reasons), or access precision positioning mode."),
            ("arrow.up.and.down.and.arrow.left.and.right", "Drag the torch to move it"),
            ("arrow.up.and.down.and.arrow.left.and.right", "Drag anywhere else to move the camera"),
            ("arrow.down.left.and.arrow.up.right", "Pinch to zoom")
        ]
    )
    
    let instructionPanel3d = InstructionPanel(
        paragraphs: [
            "In 3d view you can move around a blackhole and observe how the blackhole's extreme gravity magnifies, and warps objects behind the blackhole, even allowing you to see parts of the accretion disk that would be hidden by the blackhole if not for light bending. If you look closely you can see multiple copies of stars as they pass behind the blackhole."
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
                            .padding(.bottom, 16)
                            Button("Next") {
                                onboardingState = .onboarding(._2d)
                            }
                            .buttonStyle(.bordered)
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
                    DiagramView(tab: nil, offset: CGPoint(x: -200, y: -250))
                    
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
