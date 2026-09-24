def allocate_budget(projects: list[dict], assignments: list[dict]) -> dict[str, float]:
  #### Count project
  project = {}
  for a in assignments:
    project_id = a['project_id']
    project[project_id] = project.get(project_id,0) + 1
  #### Count budget
  budget = {}
  for p in projects:
    project_id = p['project_id']
    if project_id in project.keys():
      budget[project_id] = p['budget'] / project[project_id]
  ### Employ project
  emp_project = {}
  for a in assignments:
    employee_id = a['employee_id']
    project_id = a['project_id']
    emp_project.setdefault(employee_id,[]).append(project_id)
  ### total_budget
  total_budget = {}
  for e, p in emp_project.items():
    total_budget[e] = sum(budget[project_id] for project_id in p)
  return total_budget
