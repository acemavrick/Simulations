//
//  Spectroscape.swift
//  Simulations
//
//

import Foundation

class SpectroscapeModel: ObservableObject, HasPlayPauseToggle {
    @Published var songIndex: Int = 0
    @Published var songs: [Song] = []
    
    @Published var play = false
    @Published var stop = false
    
    init() {
        play = false
        stop = false
        
        // find any audio files in the bundle
        let fm = FileManager.default
        let path = Bundle.main.resourcePath!
        let items = try! fm.contentsOfDirectory(atPath: path)
        for item in items {
            if item.hasSuffix(".m4a") {
                songs.append(Song(name: String(item.split(separator: ".").first!), ext: "m4a"))
                print("Added \(item)")
            } else if item.hasSuffix(".aiff") {
                songs.append(Song(name: String(item.split(separator: ".").first!), ext: "aiff"))
                print("Added \(item)")
            } else if item.hasSuffix(".mp3") {
                songs.append(Song(name: String(item.split(separator: ".").first!), ext: "mp3"))
                print("Added \(item)")
            }
        }
        songs.sort(by: { $0.name < $1.name })
        songIndex = 0
    }
    
    func stopAudio() {
        play = false
        stop = true
    }
}

struct Song {
    var name: String
    var ext: String
}
