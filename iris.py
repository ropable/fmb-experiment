#!/usr/bin/python
from bottle import Bottle, request, response
import json
import os
from sqlalchemy.engine import create_engine
from sqlalchemy.orm import sessionmaker, scoped_session

dot_env = os.path.join(os.getcwd(), '.env')
if os.path.exists(dot_env):
    from dotenv import load_dotenv
    load_dotenv()
database_url = os.environ['DATABASE_URL']
engine = create_engine(database_url)
Session = scoped_session(sessionmaker(bind=engine, autoflush=True))
application = Bottle()


@application.route('/query')
def query():
    response.content_type = 'application/json'
    q = request.query.q or '5/OCT/2021'
    sql = """SELECT i.name, s.stratum, p.cell_id ||'-' || to_char( p.plot_id) plotname, gm.msmt_date, gm.created_on uploaded, gm.assessor
FROM ri_plot p
INNER JOIN ri_gnd_msmt gm ON p.plt_id = gm.plt_id
INNER JOIN ri_assign_gndmsmt_to_inv ag ON gm.gnd_ms_id = ag.gnd_ms_id
INNER JOIN ri_inventory i ON ag.inv_id = i.inv_id
LEFT OUTER JOIN ri_stratum s ON s.strat_id = ag.strat_id
WHERE gm.created_on > '{}'
ORDER BY i.name, plotname""".format(q)
    s = Session()
    result = s.execute(sql).all()
    s.close()
    j = []
    for i in result:
        j.append([i[0], i[1], i[2], i[3].isoformat(), i[4].isoformat(), i[5]])
    return json.dumps(j)


if __name__ == '__main__':
    from bottle import run
    run(application, host='0.0.0.0', port=8818)
