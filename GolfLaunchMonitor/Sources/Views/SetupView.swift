import SwiftUI

struct SetupView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Camera placement") {
                    tip("Mount your phone on a tripod or stand directly behind the ball, facing the net — roughly where your own eyes would be looking down the target line.")
                    tip("Turn the phone sideways: record in landscape, not portrait.")
                    tip("Keep the phone level and about waist height, a few feet behind the ball.")
                }

                Section("Before you swing") {
                    tip("Make sure the ball is clearly lit and stands out from the background — avoid a bright net or busy background right behind it.")
                    tip("Frame the shot so the ball, your ball-striking zone, and the net are all in view.")
                    tip("Start recording before you address the ball, and stop a moment after it hits the net.")
                }

                Section("How this works") {
                    tip("This app estimates ball speed, launch angle, direction, and carry distance purely from video — there's no radar or sensor involved, so treat the numbers as rough estimates, not precise readings.")
                    tip("It can't measure spin, so estimated carry distance is a simplified physics estimate, not a true simulation.")
                    tip("Good lighting and a stable mount matter more than anything else for accuracy.")
                }
            }
            .navigationTitle("Setup")
        }
    }

    private func tip(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(.titleOnly)
            .font(.callout)
            .padding(.vertical, 2)
    }
}

#Preview {
    SetupView()
}
