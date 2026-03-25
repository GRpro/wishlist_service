import React, { useState, useEffect } from 'react';

const API_BASE = 'http://localhost:8080/v1';
const RECO_BASE = 'http://localhost:8081/v1';

function App() {
  const [userId, setUserId] = useState('user_1');
  const [wishes, setWishes] = useState([]);
  const [recommendations, setRecommendations] = useState([]);
  const [loadingWishes, setLoadingWishes] = useState(false);
  const [loadingRecos, setLoadingRecos] = useState(false);
  const [newWish, setNewWish] = useState({ title: '', url: '', tags: '' });

  useEffect(() => {
    if (userId) {
      fetchWishes();
    }
  }, [userId]);

  const fetchWishes = async () => {
    setLoadingWishes(true);
    try {
      const res = await fetch(`${API_BASE}/wishlist?user_id=${userId}`);
      if (res.ok) {
        const data = await res.json();
        setWishes(data);
      }
    } catch (err) {
      console.error("Failed to fetch wishes", err);
    } finally {
      setLoadingWishes(false);
    }
  };

  const fetchRecommendations = async () => {
    setLoadingRecos(true);
    try {
      const res = await fetch(`${RECO_BASE}/recommendations/${userId}`);
      if (res.ok) {
        const data = await res.json();
        setRecommendations(data);
      }
    } catch (err) {
      console.error("Failed to fetch recommendations", err);
    } finally {
      setLoadingRecos(false);
    }
  };

  const addWish = async (e) => {
    e.preventDefault();
    if (!newWish.title || !newWish.url) return;

    try {
      const res = await fetch(`${API_BASE}/wishes?user_id=${userId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...newWish,
          tags: newWish.tags.split(',').map(tag => tag.trim()).filter(t => t)
        })
      });
      if (res.ok) {
        setNewWish({ title: '', url: '', tags: '' });
        fetchWishes();
      }
    } catch (err) {
      console.error("Failed to add wish", err);
    }
  };

  const deleteWish = async (wishId) => {
    if (!wishId || wishId === 'undefined') {
      console.error("Invalid wish ID:", wishId);
      return;
    }
    try {
      const res = await fetch(`${API_BASE}/wishes/${wishId}?user_id=${userId}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        fetchWishes();
      }
    } catch (err) {
      console.error("Failed to delete wish", err);
    }
  };

  return (
    <div className="container">
      <h1>Wishlists</h1>

      <div className="user-selector">
        <label>User ID:</label>
        <input
          type="text"
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          placeholder="Enter User ID..."
        />
        <button onClick={fetchWishes}>Switch User</button>
      </div>

      <div className="grid">
        <div className="section">
          <h2>My Wishes</h2>
          <form className="wish-form" onSubmit={addWish}>
            <input
              type="text"
              placeholder="Title (e.g. MacBook Pro)"
              value={newWish.title}
              onChange={(e) => setNewWish({ ...newWish, title: e.target.value })}
            />
            <input
              type="text"
              placeholder="URL"
              value={newWish.url}
              onChange={(e) => setNewWish({ ...newWish, url: e.target.value })}
            />
            <input
              type="text"
              placeholder="Tags (comma separated)"
              value={newWish.tags}
              onChange={(e) => setNewWish({ ...newWish, tags: e.target.value })}
            />
            <button type="submit">Add Wish</button>
          </form>

          <div className="list">
            {loadingWishes ? <div className="loading">Loading wishes...</div> : (
              wishes.length === 0 ? <div className="empty">No wishes yet.</div> : (
                wishes.map((wish) => (
                  <div key={wish.id} className="item">
                    <div className="item-info">
                      <a href={wish.url} target="_blank" rel="noreferrer" className="item-title">{wish.title}</a>
                      <span className="item-url">{wish.url}</span>
                      <div className="tags">
                        {wish.tags?.map(tag => <span key={tag} className="tag">{tag}</span>)}
                      </div>
                    </div>
                    <button className="delete-btn" onClick={() => deleteWish(wish.id || wish._id)}>
                      🗑️
                    </button>
                  </div>
                ))
              )
            )}
          </div>
        </div>

        <div className="section">
          <h2>
            Recommendations
            <button onClick={fetchRecommendations} disabled={loadingRecos}>
              {loadingRecos ? 'Calculating...' : 'Fetch'}
            </button>
          </h2>

          <div className="list">
            {loadingRecos ? <div className="loading">Generating personalized recommendations...</div> : (
              recommendations.length === 0 ? <div className="empty">Click Fetch to see what's trending for you!</div> : (
                recommendations.map((reco) => (
                  <div key={reco.url} className="item reco-item">
                    <div className="item-info">
                      <a href={reco.url} target="_blank" rel="noreferrer" className="item-title">{reco.title}</a>
                      <span className="item-url">{reco.url}</span>
                      <div className="tags">
                        {reco.tags?.map(tag => <span key={tag} className="tag">{tag}</span>)}
                      </div>
                    </div>
                    <div className="score">Score: {reco.score}</div>
                  </div>
                ))
              )
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
