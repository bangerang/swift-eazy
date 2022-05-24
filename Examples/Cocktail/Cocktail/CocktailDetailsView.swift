import Foundation
import SwiftUI
import Combine
import Eazy

struct CocktailDetailsState: Equatable {
    let imageLink: String?
    let id: String
    let name: String
    let instruction: String
    var isFavorite: Bool
}

enum CocktailDetailsAction: Equatable {
    case toggleFavorite
}

enum CocktailDetailsHook: CaseIterable {
    case favoriteChanged
}

struct CocktailDetailsInteractor: Interactor {
    
    let service: CocktailService
    
    func onAction(_ action: CocktailDetailsAction, store: MutatingStore<CocktailDetailsState, CocktailDetailsAction>) async {
        switch action {
        case .toggleFavorite:
            if let found = service.cocktails.first(where: { $0.idDrink == store.id }) {
                service.toggleFavorite(cocktail: found)
            }
        }
    }
    
    func publisher(for hook: CocktailDetailsHook, store: MutatingStore<CocktailDetailsState, CocktailDetailsAction>) -> AnyCancellable {
        switch hook {
        case .favoriteChanged:
            return HookPublisher(service.favoritesPublisher)
                .sink { favorites in
                    let isFavorite = service.favorites.contains(where: { $0.idDrink == store.id })
                    withAnimation {
                        store.isFavorite = isFavorite
                    }
                }
        }
    }
}

struct CocktailDetailsView: View {
    
    @StateStore var store: Store<CocktailDetailsState, CocktailDetailsAction>
    
    var body: some View {
        ScrollView {
            Group {
                if let link = store.imageLink {
                    AsyncImage(url: URL(string: link)) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                }
                Text(store.instruction)
            }.padding()
            
        }
        .navigationTitle(store.name)
        .toolbar {
            Button {
                store.dispatch(.toggleFavorite)
            } label: {
                Label("", systemImage: store.isFavorite ? "heart.fill" : "heart")
                    .labelStyle(.iconOnly)
                    .imageScale(.large)
                    .rotationEffect(.degrees(store.isFavorite ? 360 : 0))
            }
        }
    }
}

#if DEBUG
struct CocktailDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CocktailDetailsView(store: Store(state: CocktailDetailsState(imageLink: nil,
                                                                         id: "",
                                                                         name: "Vodka",
                                                                         instruction: "Shake it",
                                                                         isFavorite: true),
                                             interactor: CocktailDetailsInteractor(service: .mock)))
        }
       
    }
}
#endif
