package com.tsmediapipe.participantView

import android.annotation.SuppressLint
import android.app.Activity
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import com.tsmediapipe.R
import co.daily.model.Participant
import co.daily.model.ParticipantId
import co.daily.view.VideoView

object ParticipantOverlayManager {

    private val videoViews = mutableMapOf<ParticipantId, VideoView>()

    @SuppressLint("MissingInflatedId")
    fun showOverlay(activity: Activity, participant: Participant) {
        activity.runOnUiThread {
            val participantContainer = activity.findViewById<FrameLayout>(R.id.participant_overlay_container)
            if (participantContainer != null) {
                participantContainer.visibility = View.VISIBLE

                // Inflate the participant video layout
                val layoutInflater = LayoutInflater.from(activity)
                val participantView = layoutInflater.inflate(R.layout.participant_view, participantContainer, false)

                // Get the VideoView from the inflated layout
                val videoView = participantView.findViewById<VideoView>(R.id.participant_video)

                // Assign the track to the video view
                videoView.track = participant.media?.camera?.track

                // Store the video view for future reference
                videoViews[participant.id] = videoView

                // Add the participant view inside the overlay container
                participantContainer.addView(participantView)
            }
        }
    }

    fun hideOverlay(activity: Activity, participant: Participant) {
        activity.runOnUiThread {
            val participantContainer = activity.findViewById<FrameLayout>(R.id.participant_overlay_container)
            val videoView = videoViews.remove(participant.id)

            if (participantContainer != null && videoView != null) {
                participantContainer.removeView(videoView.parent as View)

                // Hide container if empty
                if (participantContainer.childCount == 0) {
                    participantContainer.visibility = View.GONE
                }
            }
        }
    }

    fun participantUpdated(activity: Activity, participant: Participant) {
        activity.runOnUiThread {
            val videoView = videoViews[participant.id]
            if (videoView != null) {
                videoView.track = participant.media?.camera?.track
            } else {
                videoView?.track = null
            }
        }
    }
}
